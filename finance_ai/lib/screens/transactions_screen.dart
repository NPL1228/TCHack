import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_card.dart';
import '../widgets/ai_chat_popup.dart';
import 'add_transaction_screen.dart';
import 'dashboard_screen.dart';

class _TransactionsData {
  final List<Transaction> filtered;
  final Map<DateTime, List<Transaction>> grouped;
  final double totalExpense;
  final double totalIncome;
  final FinanceProvider fp;

  _TransactionsData({
    required this.filtered,
    required this.grouped,
    required this.totalExpense,
    required this.totalIncome,
    required this.fp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TransactionsData &&
          runtimeType == other.runtimeType &&
          filtered.length == other.filtered.length &&
          totalExpense == other.totalExpense &&
          totalIncome == other.totalIncome;

  @override
  int get hashCode =>
      filtered.length.hashCode ^ totalExpense.hashCode ^ totalIncome.hashCode;
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchCtrl = TextEditingController();
  List<String> _selectedCategories = [];
  List<String> _selectedAccountIds = [];
  String  _searchQuery = '';

  // Month navigation
  late DateTime _month;

  // ── Batch selection state ─────────────────────────────────────
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _prevMonth() => setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1);
    if (!next.isAfter(DateTime(now.year, now.month))) {
      setState(() => _month = next);
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  // ── Selection helpers ─────────────────────────────────────────
  void _enterSelectionMode(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelection(String id) {
    if (!_selectionMode) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _batchDelete(FinanceProvider fp) async {
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text('Delete $count transaction${count == 1 ? '' : 's'}?',
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text('This will permanently remove the selected transaction${count == 1 ? '' : 's'}.',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppTheme.accentRed))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await fp.batchDeleteTransactions(_selectedIds.toList());
      _clearSelection();
    }
  }

  Future<void> _batchEditDate(FinanceProvider fp) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.accent, surface: AppTheme.surfaceCard),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      await fp.batchUpdateDate(_selectedIds.toList(), picked);
      _clearSelection();
      // If we edited to a different month, navigate to it
      if (picked.year != _month.year || picked.month != _month.month) {
        setState(() => _month = DateTime(picked.year, picked.month));
      }
    }
  }

  void _showFilterSheet(BuildContext context, List accounts) {
    List<String> tempCats = List.from(_selectedCategories);
    List<String> tempAccs = List.from(_selectedAccountIds);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(ctx).padding.bottom + 20),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
                )),
                Row(
                  children: [
                    const Text('Filters', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setLocal(() { tempCats.clear(); tempAccs.clear(); });
                        setState(() { _selectedCategories.clear(); _selectedAccountIds.clear(); });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Clear All', style: TextStyle(color: AppTheme.accentRed, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (accounts.isNotEmpty) ...[
                  const Text('ACCOUNT', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _buildFilterChip(label: 'All Accounts', selected: tempAccs.isEmpty, color: AppTheme.accent,
                          onTap: () => setLocal(() => tempAccs.clear())),
                      ...accounts.map((a) {
                        Color c;
                        try { c = Color(int.parse(a.colorHex.replaceFirst('#', '0xFF'))); } catch (_) { c = AppTheme.accent; }
                        return _buildFilterChip(
                          label: a.name, selected: tempAccs.contains(a.id), color: c,
                          onTap: () => setLocal(() {
                            if (tempAccs.contains(a.id)) tempAccs.remove(a.id); else tempAccs.add(a.id);
                          }),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                const Text('CATEGORY', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _buildFilterChip(label: 'All Categories', selected: tempCats.isEmpty, color: AppTheme.accent,
                        onTap: () => setLocal(() => tempCats.clear())),
                    ...AppTheme.categories.map((cat) {
                      final c = AppTheme.categoryColors[cat] ?? AppTheme.accent;
                      return _buildFilterChip(
                        label: '${AppTheme.categoryIcons[cat] ?? ''} $cat',
                        selected: tempCats.contains(cat), color: c,
                        onTap: () => setLocal(() {
                          if (tempCats.contains(cat)) tempCats.remove(cat); else tempCats.add(cat);
                        }),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() { _selectedCategories = tempCats; _selectedAccountIds = tempAccs; });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({required String label, required bool selected, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppTheme.border),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? color : AppTheme.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          fontSize: 13,
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _selectionMode
          ? AppBar(
              backgroundColor: AppTheme.surface,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _clearSelection,
              ),
              title: Text('${_selectedIds.length} selected',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
              actions: [
                Consumer<FinanceProvider>(
                  builder: (ctx, fp, _) => Row(children: [
                    IconButton(
                      icon: const Icon(Icons.calendar_today_rounded, color: AppTheme.accentBlue),
                      tooltip: 'Edit Date',
                      onPressed: () => _batchEditDate(fp),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentRed),
                      tooltip: 'Delete Selected',
                      onPressed: () => _batchDelete(fp),
                    ),
                  ]),
                ),
              ],
            )
          : AppBar(
              title: const Text('Transactions'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.auto_awesome_rounded, color: AppTheme.accentBlue),
                  tooltip: 'AiLedge Advisor',
                  onPressed: () => showAiChat(context),
                ),
                Consumer<FinanceProvider>(
                  builder: (ctx, fp, _) => Stack(
                    alignment: Alignment.topRight,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.filter_list_rounded),
                        onPressed: () => _showFilterSheet(context, fp.allAccounts),
                        tooltip: 'Filter',
                      ),
                      if (_selectedCategories.isNotEmpty || _selectedAccountIds.isNotEmpty)
                        Positioned(
                          top: 8, right: 8,
                          child: Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => showAddTransactionOptions(context),
                ),
              ],
            ),
      body: Selector<FinanceProvider, _TransactionsData>(
        selector: (ctx, fp) {
          final filtered = fp.transactionsForMonth(
            _month.year, _month.month,
            categories: _selectedCategories,
            accountIds: _selectedAccountIds,
            query:      _searchQuery.isEmpty ? null : _searchQuery,
          );
          return _TransactionsData(
            filtered: filtered,
            grouped: fp.groupByDate(filtered),
            totalExpense: filtered.where((t) => t.isExpense).fold<double>(0, (s, t) => s + t.amount),
            totalIncome: filtered.where((t) => !t.isExpense).fold<double>(0, (s, t) => s + t.amount),
            fp: fp,
          );
        },
        builder: (ctx, data, _) {
          final dates = data.grouped.keys.toList();

          return Column(
            children: [
              // ─ Month Navigator ─
              Container(
                color: AppTheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary),
                      onPressed: _prevMonth,
                    ),
                    Expanded(
                      child: Text(
                        DateFormat('MMMM yyyy').format(_month),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded,
                          color: _isCurrentMonth ? AppTheme.textMuted : AppTheme.textPrimary),
                      onPressed: _isCurrentMonth ? null : _nextMonth,
                    ),
                  ],
                ),
              ),

              // ─ Month summary ─
              Container(
                color: AppTheme.surface,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(child: _StatPill(label: 'Spent',  value: data.fp.formatCurrency(data.totalExpense), color: AppTheme.accentRed)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatPill(label: 'Earned', value: data.fp.formatCurrency(data.totalIncome),  color: AppTheme.accent)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatPill(
                        label: 'Net',
                        value: data.fp.formatCurrency((data.totalIncome - data.totalExpense).abs()),
                        color: data.totalIncome >= data.totalExpense ? AppTheme.accent : AppTheme.accentRed,
                        prefix: data.totalIncome >= data.totalExpense ? '+' : '−',
                      ),
                    ),
                  ],
                ),
              ),

              // ─ Search bar ─
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted),
                            onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                          )
                        : null,
                  ),
                ),
              ),

              // Selection mode hint bar
              if (_selectionMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  child: Text(
                    'Tap to select more · Long-press more to add',
                    style: const TextStyle(color: AppTheme.accent, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),

              const Divider(color: AppTheme.border, height: 1),

              // ─ Date-grouped list ─
              Expanded(
                child: data.filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🗓️', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text('No transactions in\n${DateFormat('MMMM yyyy').format(_month)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: dates.length,
                        itemBuilder: (ctx, i) {
                          final date = dates[i];
                          final txns = data.grouped[date]!;
                          return _DateGroup(
                            date: date,
                            transactions: txns,
                            selectedIds: _selectedIds,
                            selectionMode: _selectionMode,
                            onLongPress: (id) => _enterSelectionMode(id),
                            onToggleSelect: (id) => _toggleSelection(id),
                            onDelete: (id) => data.fp.deleteTransaction(id),
                            onEdit: (t) => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AddTransactionScreen(
                                prefill: {
                                  'id':           t.id,
                                  'store_name':   t.storeName,
                                  'title':        t.title,
                                  'total_amount': t.amount,
                                  'category':     t.category,
                                  'date':         t.date.toIso8601String(),
                                  'is_expense':   t.isExpense,
                                  'notes':        t.notes,
                                  'account_id':   t.accountId,
                                },
                              )),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String prefix;
  const _StatPill({required this.label, required this.value, required this.color, this.prefix = ''});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        Text('$prefix$value', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Date Group
// ─────────────────────────────────────────────────────────────
class _DateGroup extends StatelessWidget {
  final DateTime date;
  final List<Transaction> transactions;
  final Set<String> selectedIds;
  final bool selectionMode;
  final void Function(String id) onLongPress;
  final void Function(String id) onToggleSelect;
  final void Function(String id) onDelete;
  final void Function(Transaction t) onEdit;

  const _DateGroup({
    required this.date,
    required this.transactions,
    required this.selectedIds,
    required this.selectionMode,
    required this.onLongPress,
    required this.onToggleSelect,
    required this.onDelete,
    required this.onEdit,
  });

  String _formatDate(DateTime d) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yest  = today.subtract(const Duration(days: 1));
    final target= DateTime(d.year, d.month, d.day);
    if (target == today) return 'Today';
    if (target == yest)  return 'Yesterday';
    return DateFormat('EEEE, d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final fp       = context.read<FinanceProvider>();
    final dayTotal = transactions.where((t) => t.isExpense).fold<double>(0, (s, t) => s + t.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Text(_formatDate(date), style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.3)),
              const Spacer(),
              if (dayTotal > 0)
                Text('-${fp.formatCurrency(dayTotal)}',
                    style: const TextStyle(color: AppTheme.accentRed, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        // Transactions
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: List.generate(transactions.length, (i) {
              final t      = transactions[i];
              final isLast = i == transactions.length - 1;
              final isSelected = selectedIds.contains(t.id);

              return Column(
                children: [
                  // In selection mode: tap = toggle, no swipe-to-delete
                  if (selectionMode)
                    _SelectableTile(
                      transaction: t,
                      isSelected: isSelected,
                      isLast: isLast,
                      onTap: () => onToggleSelect(t.id),
                      onLongPress: () => onLongPress(t.id),
                    )
                  else
                    Dismissible(
                      key: Key(t.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: AppTheme.accentRed.withValues(alpha: 0.15),
                        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentRed),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: AppTheme.surfaceCard,
                            title: const Text('Delete?', style: TextStyle(color: AppTheme.textPrimary)),
                            content: Text('Remove "${t.title}"?', style: const TextStyle(color: AppTheme.textSecondary)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
                              TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Delete', style: TextStyle(color: AppTheme.accentRed))),
                            ],
                          ),
                        ) ?? false;
                      },
                      onDismissed: (_) => onDelete(t.id),
                      child: InkWell(
                        onTap: () => onEdit(t),
                        onLongPress: () => onLongPress(t.id),
                        borderRadius: BorderRadius.circular(isLast ? 16 : 0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: TransactionCard(transaction: t),
                        ),
                      ),
                    ),
                  if (!isLast) const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(color: AppTheme.border, height: 1)),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ── Selectable tile for batch-selection mode ──────────────────
class _SelectableTile extends StatelessWidget {
  final Transaction transaction;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SelectableTile({
    required this.transaction,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(isLast ? 16 : 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected ? AppTheme.accent.withValues(alpha: 0.1) : Colors.transparent,
        child: Row(
          children: [
            // Animated checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? AppTheme.accent : AppTheme.textMuted,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, color: Colors.black, size: 14)
                    : null,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 4, top: 2, bottom: 2),
                child: TransactionCard(transaction: transaction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
