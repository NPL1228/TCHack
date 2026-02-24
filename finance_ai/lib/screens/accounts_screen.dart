import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.accent;
    }
  }

  IconData _icon(String name) {
    const map = {
      'account_balance':         Icons.account_balance_rounded,
      'account_balance_wallet':  Icons.account_balance_wallet_rounded,
      'payments':                Icons.payments_rounded,
      'credit_card':             Icons.credit_card_rounded,
    };
    return map[name] ?? Icons.wallet_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Accounts')),
      body: Consumer<FinanceProvider>(
        builder: (ctx, fp, _) {
          final accounts = fp.allAccounts;
          final fmt      = NumberFormat('#,##0.00');

          // Group by type
          final Map<String, List<Account>> grouped = {};
          for (final a in accounts) {
            grouped.putIfAbsent(a.type, () => []).add(a);
          }
          final typeOrder = AccountConfig.types.where(grouped.containsKey).toList();

          return Column(
            children: [
              // ─ Total balance banner ─
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Balance', style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(
                      fp.formatCurrency(fp.totalBalance),
                      style: const TextStyle(color: Colors.black, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1),
                    ),
                    Text('Across ${accounts.length} account${accounts.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),

              // ─ Accounts list ─
              Expanded(
                child: accounts.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🏦', style: TextStyle(fontSize: 52)),
                            SizedBox(height: 12),
                            Text('No accounts yet.\nTap + to add one!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        children: [
                          for (final type in typeOrder) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                              child: Row(
                                children: [
                                  Text(type, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Divider(color: AppTheme.border)),
                                ],
                              ),
                            ),
                            for (final acc in grouped[type]!)
                              _AccountCard(
                                account:  acc,
                                hexColor: _hexColor(acc.colorHex),
                                icon:     _icon(acc.iconName),
                                fmt:      fmt,
                                onEdit: () => _showEditAccount(context, acc),
                                onDelete: () async {
                                  final ok = await showDialog<bool>(
                                    context: ctx,
                                    builder: (_) => AlertDialog(
                                      backgroundColor: AppTheme.surfaceCard,
                                      title: const Text('Delete Account', style: TextStyle(color: AppTheme.textPrimary)),
                                      content: Text('Remove "${acc.name}"?', style: const TextStyle(color: AppTheme.textSecondary)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
                                        TextButton(onPressed: () => Navigator.pop(ctx, true),  child: const Text('Delete', style: TextStyle(color: AppTheme.accentRed))),
                                      ],
                                    ),
                                  );
                                  if (ok == true) await fp.deleteAccount(acc.id);
                                },
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccount(context),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _showAddAccount(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AddAccountSheet(),
    );
  }

  void _showEditAccount(BuildContext context, Account account) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditAccountSheet(account: account),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Account Card
// ─────────────────────────────────────────────────────────────
class _AccountCard extends StatelessWidget {
  final Account account;
  final Color hexColor;
  final IconData icon;
  final NumberFormat fmt;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _AccountCard({
    required this.account,
    required this.hexColor,
    required this.icon,
    required this.fmt,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FinanceProvider>();
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: hexColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: hexColor, size: 24),
          ),
          title: Text(account.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          subtitle: Text(account.type, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    fp.formatCurrency(account.balance, currency: account.currency),
                    style: TextStyle(
                      color: account.balance >= 0 ? AppTheme.accent : AppTheme.accentRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const Text('balance', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Add Account Bottom Sheet
// ─────────────────────────────────────────────────────────────
class _AddAccountSheet extends StatefulWidget {
  const _AddAccountSheet();
  @override
  State<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<_AddAccountSheet> {
  final _nameCtrl    = TextEditingController();
  final _balanceCtrl = TextEditingController();
  String _selectedType = AccountConfig.types.first;
  String _selectedCurrency = 'MYR';
  static const List<String> _currencies = ['MYR', 'USD', 'EUR', 'GBP', 'SGD', 'JPY'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.read<FinanceProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add Account', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 20),

          // Name field
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Account Name',
              hintText: 'e.g. Maybank Savings, Touch \'n Go',
            ),
          ),
          const SizedBox(height: 16),

          // Type picker
          const Text('Account Type', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: AccountConfig.types.map((type) {
              final selected = type == _selectedType;
              final c = Color(int.parse(
                AccountConfig.typeColors[type]!.replaceFirst('#', '0xFF'),
              ));
              return GestureDetector(
                onTap: () => setState(() => _selectedType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? c.withValues(alpha: 0.2) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? c : AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconForType(type),
                        size: 14,
                        color: selected ? c : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        type,
                        style: TextStyle(
                          color: selected ? c : AppTheme.textSecondary,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Currency picker
          const Text('Currency', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCurrency,
                dropdownColor: AppTheme.surfaceCard,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                isExpanded: true,
                items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedCurrency = v!),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Balance field
          TextField(
            controller: _balanceCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(
              labelText: 'Current Balance',
              prefixText: '${fp.getCurrencySymbol(_selectedCurrency)}  ',
              prefixStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 16),
              hintText: '0.00',
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: () async {
              final name    = _nameCtrl.text.trim();
              final balance = double.tryParse(_balanceCtrl.text) ?? 0;
              if (name.isEmpty) return;
              await fp.addAccount(
                name:     name,
                type:     _selectedType,
                balance:  balance,
                colorHex: AccountConfig.typeColors[_selectedType]!,
                iconName: AccountConfig.typeIcons[_selectedType]!,
                currency: _selectedCurrency,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save Account'),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String t) => {
    'Bank':     Icons.account_balance_rounded,
    'E-Wallet': Icons.account_balance_wallet_rounded,
    'Cash':     Icons.payments_rounded,
    'Card':     Icons.credit_card_rounded,
  }[t] ?? Icons.wallet_rounded;
}

// ─────────────────────────────────────────────────────────────
// Edit Account Bottom Sheet
// ─────────────────────────────────────────────────────────────
class _EditAccountSheet extends StatefulWidget {
  final Account account;
  const _EditAccountSheet({required this.account});
  @override
  State<_EditAccountSheet> createState() => _EditAccountSheetState();
}

class _EditAccountSheetState extends State<_EditAccountSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _balanceCtrl;
  late String _selectedType;
  late String _selectedCurrency;
  static const List<String> _currencies = ['MYR', 'USD', 'EUR', 'GBP', 'SGD', 'JPY'];

  @override
  void initState() {
    super.initState();
    _nameCtrl    = TextEditingController(text: widget.account.name);
    _balanceCtrl = TextEditingController(text: widget.account.balance.toStringAsFixed(2));
    _selectedType = widget.account.type;
    // ensure backwards compat for old accounts
    _selectedCurrency = _currencies.contains(widget.account.currency) ? widget.account.currency : 'MYR';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  IconData _iconForType(String t) => {
    'Bank':     Icons.account_balance_rounded,
    'E-Wallet': Icons.account_balance_wallet_rounded,
    'Cash':     Icons.payments_rounded,
    'Card':     Icons.credit_card_rounded,
  }[t] ?? Icons.wallet_rounded;

  @override
  Widget build(BuildContext context) {
    final fp = context.read<FinanceProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Edit Account', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppTheme.surfaceCard,
                      title: const Text('Delete Account', style: TextStyle(color: AppTheme.textPrimary)),
                      content: Text('Remove "${widget.account.name}"?', style: const TextStyle(color: AppTheme.textSecondary)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
                        TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Delete', style: TextStyle(color: AppTheme.accentRed))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await fp.deleteAccount(widget.account.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentRed, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Account Name'),
          ),
          const SizedBox(height: 16),

          const Text('Account Type', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: AccountConfig.types.map((type) {
              final selected = type == _selectedType;
              final c = Color(int.parse(AccountConfig.typeColors[type]!.replaceFirst('#', '0xFF')));
              return GestureDetector(
                onTap: () => setState(() => _selectedType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? c.withValues(alpha: 0.2) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? c : AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconForType(type), size: 14, color: selected ? c : AppTheme.textMuted),
                      const SizedBox(width: 6),
                      Text(type, style: TextStyle(color: selected ? c : AppTheme.textSecondary, fontWeight: selected ? FontWeight.w700 : FontWeight.normal, fontSize: 13)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Currency picker
          const Text('Currency', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCurrency,
                dropdownColor: AppTheme.surfaceCard,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                isExpanded: true,
                items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedCurrency = v!),
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _balanceCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(
              labelText: 'Balance',
              prefixText: '${fp.getCurrencySymbol(_selectedCurrency)}  ',
              prefixStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 16),
              hintText: '0.00',
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: () async {
              final name    = _nameCtrl.text.trim();
              final balance = double.tryParse(_balanceCtrl.text) ?? widget.account.balance;
              if (name.isEmpty) return;
              // Delete old + re-add with same ID via updateAccount if available,
              // otherwise replicate via deleteAccount + addAccount
              await fp.deleteAccount(widget.account.id);
              await fp.addAccount(
                name:     name,
                type:     _selectedType,
                balance:  balance,
                colorHex: AccountConfig.typeColors[_selectedType]!,
                iconName: AccountConfig.typeIcons[_selectedType]!,
                currency: _selectedCurrency,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}
