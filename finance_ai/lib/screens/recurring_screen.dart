import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import 'add_transaction_screen.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  final Map<String, bool> _expanded = {};

  static const _periodLabels = {
    'daily':   'Daily',
    'weekly':  'Weekly',
    'monthly': 'Monthly',
    'yearly':  'Yearly',
  };

  static const _periodIcons = {
    'daily':   Icons.today_rounded,
    'weekly':  Icons.view_week_rounded,
    'monthly': Icons.calendar_month_rounded,
    'yearly':  Icons.event_repeat_rounded,
  };

  Map<String, List<Transaction>> _groupByPeriod(List<Transaction> templates) {
    final Map<String, List<Transaction>> result = {};
    for (final t in templates) {
      final key = t.recurringPeriod ?? 'monthly';
      result.putIfAbsent(key, () => []).add(t);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final fp        = context.watch<FinanceProvider>();
    final templates = fp.recurringTemplates;
    final grouped   = _groupByPeriod(templates);
    final periods   = ['daily', 'weekly', 'monthly', 'yearly'];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Recurring Transactions'),
        leading: BackButton(color: AppTheme.textPrimary),
      ),
      body: templates.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔁', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('No recurring transactions yet.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('Add one via the + button and enable\nthe recurring toggle.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final period in periods)
                  if (grouped.containsKey(period)) ...[
                    _PeriodGroup(
                      period: period,
                      label: _periodLabels[period] ?? period,
                      icon: _periodIcons[period] ?? Icons.repeat_rounded,
                      templates: grouped[period]!,
                      expanded: _expanded[period] ?? true,
                      onToggle: () => setState(() =>
                          _expanded[period] = !(_expanded[period] ?? true)),
                      fp: fp,
                      onDelete: (id) async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: AppTheme.surfaceCard,
                            title: const Text('Delete Recurring?',
                                style: TextStyle(color: AppTheme.textPrimary)),
                            content: const Text(
                                'This removes the recurring template and its original transaction entry.',
                                style: TextStyle(color: AppTheme.textSecondary)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel',
                                    style: TextStyle(color: AppTheme.textMuted)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete',
                                    style: TextStyle(color: AppTheme.accentRed)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          await context.read<FinanceProvider>().deleteRecurringTemplate(id);
                        }
                      },
                      onToggleActive: (t) async {
                        t.isRecurring = !t.isRecurring;
                        await context.read<FinanceProvider>().updateRecurringTemplate(t);
                      },
                      onChangePeriod: (t, period) async {
                        t.recurringPeriod = period;
                        await context.read<FinanceProvider>().updateRecurringTemplate(t);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AddTransactionScreen(
              prefill: {'is_recurring': true},
            ),
          ),
        ),
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
    );
  }
}

// ── Period group widget ────────────────────────────────────────
class _PeriodGroup extends StatelessWidget {
  final String period;
  final String label;
  final IconData icon;
  final List<Transaction> templates;
  final bool expanded;
  final VoidCallback onToggle;
  final FinanceProvider fp;
  final void Function(String id) onDelete;
  final void Function(Transaction t) onToggleActive;
  final void Function(Transaction t, String period) onChangePeriod;

  const _PeriodGroup({
    required this.period,
    required this.label,
    required this.icon,
    required this.templates,
    required this.expanded,
    required this.onToggle,
    required this.fp,
    required this.onDelete,
    required this.onToggleActive,
    required this.onChangePeriod,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // Header row – tap to collapse / expand
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppTheme.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label,
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${templates.length}',
                        style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),

          // Template cards
          if (expanded) ...[
            const Divider(color: AppTheme.border, height: 1),
            ...List.generate(templates.length, (i) {
              final t      = templates[i];
              final isLast = i == templates.length - 1;
              return Column(
                children: [
                  _RecurringTile(
                    transaction: t,
                    fp: fp,
                    onDelete: () => onDelete(t.id),
                    onToggleActive: () => onToggleActive(t),
                    onChangePeriod: (p) => onChangePeriod(t, p),
                  ),
                  if (!isLast) const Divider(color: AppTheme.border, height: 1, indent: 16, endIndent: 16),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ── Single recurring tile ─────────────────────────────────────
class _RecurringTile extends StatelessWidget {
  final Transaction transaction;
  final FinanceProvider fp;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final void Function(String period) onChangePeriod;

  static const _periods = ['daily', 'weekly', 'monthly', 'yearly'];

  const _RecurringTile({
    required this.transaction,
    required this.fp,
    required this.onDelete,
    required this.onToggleActive,
    required this.onChangePeriod,
  });

  @override
  Widget build(BuildContext context) {
    final t      = transaction;
    final color  = t.isExpense ? AppTheme.accentRed : AppTheme.accent;
    final nextFmt = t.recurringNextDate != null
        ? DateFormat('dd MMM yyyy').format(t.recurringNextDate!)
        : 'N/A';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + amount row
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('Next: $nextFmt',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
            Text(
              '${t.isExpense ? '-' : '+'}${fp.formatCurrency(t.amount)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ]),
          const SizedBox(height: 10),

          // Period chips row
          Row(children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                children: _periods.map((p) {
                  final sel = t.recurringPeriod == p;
                  return GestureDetector(
                    onTap: () => onChangePeriod(p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? AppTheme.accent : AppTheme.border),
                      ),
                      child: Text(
                        p[0].toUpperCase() + p.substring(1),
                        style: TextStyle(
                          color: sel ? AppTheme.accent : AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 8),
            // Active toggle
            Switch(
              value: t.isRecurring,
              activeColor: AppTheme.accent,
              onChanged: (_) => onToggleActive(),
            ),
            // Delete
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentRed, size: 20),
              onPressed: onDelete,
              tooltip: 'Delete',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ]),
        ],
      ),
    );
  }
}
