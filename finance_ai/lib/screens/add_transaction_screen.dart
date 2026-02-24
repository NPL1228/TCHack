import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../services/gemini_service.dart';
import '../services/settings_service.dart';
import '../services/subcategory_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final Map<String, dynamic>? prefill;

  const AddTransactionScreen({super.key, this.prefill});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

// Transaction mode: expense, income, or transfer
enum _TxnMode { expense, income, transfer }

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _storeCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _notesCtrl;

  late String _category;
  DateTime _date = DateTime.now();
  _TxnMode _mode = _TxnMode.expense;
  bool _isSaving = false;
  bool _isCategorizing = false;
  String? _selectedAccountId;
  String? _toAccountId; // for transfer
  String? _subcategory;

  // Recurring
  bool _isRecurring = false;
  String _recurringPeriod = 'monthly';

  static const _recurringOptions = ['daily', 'weekly', 'monthly', 'yearly'];

  // ── Income categories ────────────────────────────────────────
  static const List<String> _incomeCategories = [
    'Salary', 'Allowance', 'Investment', 'Freelance',
    'Business', 'Gift', 'Rental', 'Other Income',
  ];

  bool get _isExpense => _mode == _TxnMode.expense;
  bool get _isTransfer => _mode == _TxnMode.transfer;

  String get _defaultCategory {
    if (_isTransfer) return 'Transfer';
    if (_isExpense)  return AppTheme.categories.contains(_category) ? _category : 'Other';
    return _incomeCategories.contains(_category) ? _category : 'Salary';
  }

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    _titleCtrl  = TextEditingController(text: p?['title'] ?? p?['store_name'] ?? '');
    _storeCtrl  = TextEditingController(text: p?['store_name'] ?? '');
    _amountCtrl = TextEditingController(text: p?['total_amount']?.toStringAsFixed(2) ?? '');
    _notesCtrl  = TextEditingController(text: p?['notes'] ?? '');

    final preIsExpense = p?['is_expense'] ?? true;
    _mode = preIsExpense ? _TxnMode.expense : _TxnMode.income;

    final prefillCat = p?['category'] as String?;
    _category = prefillCat ?? (_isExpense ? 'Other' : 'Salary');

    if (p?['date'] != null) {
      try { _date = DateTime.parse(p!['date']); } catch (_) {}
    }

    // Handle recurring prefill
    _isRecurring = p?['is_recurring'] ?? false;
    if (p?['recurring_period'] != null) {
      _recurringPeriod = p!['recurring_period'];
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fp = context.read<FinanceProvider>();
      if (fp.allAccounts.isNotEmpty && _selectedAccountId == null) {
        final prefillAccId = widget.prefill?['account_id'] as String?;
        final isValidId = prefillAccId != null && fp.allAccounts.any((a) => a.id == prefillAccId);
        setState(() => _selectedAccountId = isValidId ? prefillAccId : fp.allAccounts.first.id);
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _storeCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onModeSwitch(_TxnMode m) {
    setState(() {
      _mode = m;
      if (m == _TxnMode.expense && !AppTheme.categories.contains(_category)) _category = 'Other';
      if (m == _TxnMode.income  && !_incomeCategories.contains(_category))    _category = 'Salary';
      _subcategory = null;
    });
  }

  Future<void> _autoCategorize() async {
    if (_titleCtrl.text.isEmpty && _storeCtrl.text.isEmpty) return;
    setState(() => _isCategorizing = true);
    final cat = await GeminiService.categorizeTransaction(_titleCtrl.text, _storeCtrl.text);
    if (AppTheme.categories.contains(cat)) {
      setState(() { _category = cat; _isCategorizing = false; });
    } else {
      setState(() => _isCategorizing = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final fp    = context.read<FinanceProvider>();
    final items = (widget.prefill?['items'] as List?)?.cast<String>();
    final editId = widget.prefill?['id'] as String?;
    if (editId != null) await fp.deleteTransaction(editId);

    if (_isTransfer) {
      // ── Transfer path ────────────────────────────────────────
      if (_toAccountId == null || _selectedAccountId == null) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select both accounts'), backgroundColor: AppTheme.accentRed),
        );
        return;
      }
      final fromAcc = fp.accountById(_selectedAccountId!);
      await fp.addTransfer(
        fromAccountId: _selectedAccountId!,
        toAccountId:   _toAccountId!,
        amount:        double.parse(_amountCtrl.text),
        currency:      fromAcc?.currency ?? fp.mainCurrency,
        date:          _date,
        notes:         _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
    } else {
      // ── Normal transaction path ───────────────────────────────
      final selectedAcc = _selectedAccountId != null ? fp.accountById(_selectedAccountId!) : null;
      final currency    = selectedAcc?.currency ?? fp.mainCurrency;
      final nextDate    = _isRecurring
          ? _advanceDate(_date, _recurringPeriod)
          : null;

      await fp.addTransaction(
        title:              _titleCtrl.text.trim(),
        storeName:          _isExpense ? _storeCtrl.text.trim() : '',
        amount:             double.parse(_amountCtrl.text),
        category:           _defaultCategory,
        date:               _date,
        currency:           currency,
        isExpense:          _isExpense,
        notes:              _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        items:              items,
        accountId:          _selectedAccountId,
        isRecurring:        _isRecurring,
        recurringPeriod:    _isRecurring ? _recurringPeriod : null,
        recurringNextDate:  nextDate,
        subcategory:        _subcategory,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isTransfer ? 'Transfer saved!' : 'Transaction saved!'),
          backgroundColor: AppTheme.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    }
  }

  DateTime _advanceDate(DateTime d, String period) {
    switch (period) {
      case 'daily':   return DateTime(d.year, d.month, d.day + 1);
      case 'weekly':  return DateTime(d.year, d.month, d.day + 7);
      case 'monthly': return DateTime(d.year, d.month + 1, d.day);
      case 'yearly':  return DateTime(d.year + 1, d.month, d.day);
      default:        return DateTime(d.year, d.month + 1, d.day);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.accent, surface: AppTheme.surfaceCard),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FinanceProvider>();
    final accounts = fp.allAccounts;
    final selectedAcc = _selectedAccountId != null ? fp.accountById(_selectedAccountId!) : null;
    final currency = selectedAcc?.currency ?? fp.mainCurrency;
    final sym = fp.getCurrencySymbol(currency);

    final isEdit    = widget.prefill?['id'] != null;
    final isReceipt = widget.prefill != null && !isEdit;
    final subcatEnabled = SettingsService.subcategoriesEnabled;
    final recurEnabled  = SettingsService.recurringEnabled;

    final subcats = subcatEnabled ? SubcategoryService.subcategoriesFor(_defaultCategory) : <String>[];

    String screenTitle;
    if (isEdit)         screenTitle = 'Edit Transaction';
    else if (isReceipt) screenTitle = 'Review Receipt Details';
    else                screenTitle = 'Add Transaction';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(screenTitle),
        leading: BackButton(color: AppTheme.textPrimary),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Receipt banner ──────────────────────────────────
              if (isReceipt) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 16),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'AI extracted these details — please review and edit before saving.',
                          style: TextStyle(color: AppTheme.accent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Mode tabs: Expense / Income / Transfer ───────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    _TypeTab(label: '📤 Expense',  selected: _mode == _TxnMode.expense,  color: AppTheme.accentRed,   onTap: () => _onModeSwitch(_TxnMode.expense)),
                    _TypeTab(label: '📥 Income',   selected: _mode == _TxnMode.income,   color: AppTheme.accent,      onTap: () => _onModeSwitch(_TxnMode.income)),
                    _TypeTab(label: '↔ Transfer',  selected: _mode == _TxnMode.transfer, color: AppTheme.accentBlue,  onTap: () => _onModeSwitch(_TxnMode.transfer)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Amount ───────────────────────────────────────────
              _buildLabel('Amount ($sym)'),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixText: '$sym  ',
                  prefixStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 20),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter amount';
                  if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── TRANSFER specific fields ─────────────────────────
              if (_isTransfer) ...[
                _buildLabel('From Account'),
                _accountDropdown(
                  value: _selectedAccountId,
                  hint: 'Select source account',
                  accounts: accounts,
                  fp: fp,
                  onChanged: (v) => setState(() => _selectedAccountId = v),
                ),
                const SizedBox(height: 12),
                const Center(child: Icon(Icons.swap_vert_rounded, color: AppTheme.accentBlue, size: 28)),
                const SizedBox(height: 12),
                _buildLabel('To Account'),
                _accountDropdown(
                  value: _toAccountId,
                  hint: 'Select destination account',
                  accounts: accounts.where((a) => a.id != _selectedAccountId).toList(),
                  fp: fp,
                  onChanged: (v) => setState(() => _toAccountId = v),
                ),
                const SizedBox(height: 16),
                _buildLabel('Date'),
                _datePicker(),
                const SizedBox(height: 16),
                _buildLabel('Notes (optional)'),
                TextFormField(controller: _notesCtrl, style: const TextStyle(color: AppTheme.textPrimary), maxLines: 2,
                    decoration: const InputDecoration(hintText: 'e.g. Moving savings...')),
              ],

              // ── EXPENSE / INCOME specific fields ─────────────────
              if (!_isTransfer) ...[
                _buildLabel(_isExpense ? 'Description' : 'Income Source'),
                TextFormField(
                  controller: _titleCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: _isExpense ? 'e.g. Lunch at McDonald\'s' : 'e.g. Monthly salary',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => v == null || v.isEmpty ? 'Enter a description' : null,
                ),
                const SizedBox(height: 16),

                _buildLabel('Category'),
                _CategoryPicker(
                  value: _category,
                  isExpense: _isExpense,
                  onChanged: (v) => setState(() { _category = v; _subcategory = null; }),
                ),
                
                // Subcategories Add-on
                if (subcatEnabled && subcats.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildLabel('Subcategory (Optional)'),
                  DropdownButtonFormField<String>(
                    value: subcats.contains(_subcategory) ? _subcategory : null, // Ensure value is in subcats or null
                    dropdownColor: AppTheme.surfaceCard,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('None', style: TextStyle(color: AppTheme.textSecondary))),
                      ...subcats.map((sc) => DropdownMenuItem(value: sc, child: Text(sc, style: const TextStyle(color: AppTheme.textPrimary)))),
                    ],
                    onChanged: (v) => setState(() => _subcategory = v),
                  ),
                ],

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Date'),
                          _datePicker(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Account'),
                          _accountDropdown(
                            value: _selectedAccountId,
                            hint: 'Select account',
                            accounts: accounts,
                            fp: fp,
                            onChanged: (v) => setState(() => _selectedAccountId = v),
                            showNone: true, // Added showNone for consistency with original
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // AI categorize button for Expenses
                if (_isExpense && _titleCtrl.text.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _isCategorizing ? null : _autoCategorize,
                      icon: _isCategorizing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                          : const Icon(Icons.auto_awesome_rounded, size: 18, color: AppTheme.accent),
                      label: Text(_isCategorizing ? 'Categorizing...' : 'Auto-Categorize',
                          style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                if (_isExpense) ...[
                  _buildLabel('Store / Vendor (optional)'),
                  TextFormField(
                    controller: _storeCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(hintText: 'e.g. McDonald\'s Sunway'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                ],

                _buildLabel('Notes (optional)'),
                TextFormField(
                  controller: _notesCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Add some context...'),
                ),

                // ── Recurring Toggle ──────────────────────────────────
                if (recurEnabled && !_isTransfer) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Recurring Transaction', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Automatically repeat this transaction', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          value: _isRecurring,
                          activeColor: AppTheme.accent,
                          onChanged: (v) => setState(() => _isRecurring = v),
                        ),
                        if (_isRecurring) ...[
                          const Divider(color: AppTheme.border),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Repeat Every', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                              const Spacer(),
                              DropdownButton<String>(
                                value: _recurringPeriod,
                                dropdownColor: AppTheme.surfaceCard,
                                underline: const SizedBox(),
                                items: _recurringOptions.map((o) => DropdownMenuItem(
                                  value: o,
                                  child: Text(o[0].toUpperCase() + o.substring(1), style: const TextStyle(color: AppTheme.textPrimary)),
                                )).toList(),
                                onChanged: (v) => setState(() => _recurringPeriod = v!),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 32),

              // ── Save button ──────────────────────────────────────
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTransfer ? AppTheme.accentBlue
                      : (_isExpense ? AppTheme.accentRed : AppTheme.accent),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        isEdit ? 'Save Changes' : (_isTransfer ? 'Save Transfer' : (_isExpense ? 'Save Expense' : 'Save Income')),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datePicker() => GestureDetector(
    onTap: _pickDate,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, color: AppTheme.textMuted, size: 18),
          const SizedBox(width: 12),
          Text(DateFormat('dd MMM yyyy').format(_date), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
        ],
      ),
    ),
  );

  Widget _accountDropdown({
    required String? value,
    required String hint,
    required List accounts,
    required FinanceProvider fp,
    required ValueChanged<String?> onChanged,
    bool showNone = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: AppTheme.textMuted)),
          dropdownColor: AppTheme.surfaceCard,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          isExpanded: true,
          items: [
            if (showNone) const DropdownMenuItem(value: null, child: Text('None', style: TextStyle(color: AppTheme.textMuted))),
            ...accounts.map<DropdownMenuItem<String?>>((a) {
              Color ac;
              try { ac = Color(int.parse(a.colorHex.replaceFirst('#', '0xFF'))); } catch (_) { ac = AppTheme.accent; }
              return DropdownMenuItem(
                value: a.id as String?,
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: ac, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${a.name} (${fp.formatCurrency(a.balance, currency: a.currency)})', overflow: TextOverflow.ellipsis)),
                ]),
              );
            }),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
  );
}

// ── Category Picker ──────────────────────────────────────────
class _CategoryPicker extends StatelessWidget {
  final String value;
  final bool isExpense;
  final ValueChanged<String> onChanged;

  const _CategoryPicker({required this.value, required this.isExpense, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cats   = isExpense ? AppTheme.categories  : AppTheme.incomeCategories;
    final colors = isExpense ? AppTheme.categoryColors : AppTheme.incomeCategoryColors;
    final icons  = isExpense ? AppTheme.categoryIcons  : AppTheme.incomeCategoryIcons;
    final safeValue = cats.contains(value) ? value : cats.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          dropdownColor: AppTheme.surfaceCard,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          isExpanded: true,
          items: cats.map((cat) {
            final color = colors[cat] ?? AppTheme.accent;
            final icon  = icons[cat] ?? '📦';
            return DropdownMenuItem(
              value: cat,
              child: Row(children: [
                Text(icon),
                const SizedBox(width: 10),
                Text(cat, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
              ]),
            );
          }).toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }
}

// ── Type Tab ─────────────────────────────────────────────────
class _TypeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeTab({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? color : AppTheme.textMuted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
