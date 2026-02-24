import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:percent_indicator/percent_indicator.dart';
import '../providers/finance_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  void _showSetBudget(BuildContext ctx, FinanceProvider fp, String category) {
    final ctrl = TextEditingController();
    final existing = fp.budgetMap[category];
    if (existing != null) ctrl.text = existing.toStringAsFixed(2);

    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppTheme.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(AppTheme.categoryIcons[category] ?? '📦', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Text('Set Budget: $category', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(prefixText: 'RM  ', prefixStyle: TextStyle(color: AppTheme.textMuted, fontSize: 20), hintText: '0.00'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final v = double.tryParse(ctrl.text);
                if (v != null && v > 0) {
                  await fp.setBudget(category, v);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save Budget'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Budget')),
      body: Selector<FinanceProvider, _BudgetData>(
        selector: (ctx, fp) {
          final budget = fp.budgetMap;
          final spent  = AnalyticsService.spendingByCategory(fp.thisMonthTransactions);
          return _BudgetData(
            budget: budget,
            spent: spent,
            totalBudget: budget.values.fold(0, (s, v) => s + v),
            totalSpent: fp.totalExpense,
            fp: fp,
          );
        },
        builder: (ctx, data, _) {
          final budget = data.budget;
          final spent  = data.spent;
          final totalBudget = data.totalBudget;
          final totalSpent  = data.totalSpent;
          
          double overallPct  = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0;
          Color  overallColor = overallPct < 0.7 ? AppTheme.accent : overallPct < 0.9 ? AppTheme.accentGold : AppTheme.accentRed;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall budget card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [overallColor.withOpacity(0.2), overallColor.withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: overallColor.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monthly Overview', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data.fp.formatCurrency(totalSpent), style: TextStyle(color: overallColor, fontSize: 28, fontWeight: FontWeight.w800)),
                                Text('of ${data.fp.formatCurrency(totalBudget)} budgeted', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                              ],
                            ),
                          ),
                          CircularPercentIndicator(
                            radius: 36,
                            lineWidth: 6,
                            percent: overallPct,
                            center: Text('${(overallPct * 100).toInt()}%', style: TextStyle(color: overallColor, fontWeight: FontWeight.w700, fontSize: 12)),
                            progressColor: overallColor,
                            backgroundColor: AppTheme.border,
                            circularStrokeCap: CircularStrokeCap.round,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Per-category budgets
                const Text('Category Budgets', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 12),

                ...AppTheme.categories.map((cat) {
                  final budgetAmt = budget[cat] ?? 0;
                  final spentAmt  = spent[cat] ?? 0;
                  final pct       = budgetAmt > 0 ? (spentAmt / budgetAmt).clamp(0.0, 2.0) : 0.0;
                  final catColor  = AppTheme.categoryColors[cat]!;
                  Color barColor  = pct < 0.7 ? catColor : pct < 1.0 ? AppTheme.accentGold : AppTheme.accentRed;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: pct >= 1.0 ? AppTheme.accentRed.withOpacity(0.4) : AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(AppTheme.categoryIcons[cat] ?? '📦', style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(cat, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                            ),
                            GestureDetector(
                              onTap: () => _showSetBudget(ctx, data.fp, cat),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: catColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  budgetAmt > 0 ? data.fp.formatCurrency(budgetAmt) : 'Set Budget',
                                  style: TextStyle(color: catColor, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (budgetAmt > 0) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct.toDouble().clamp(0.0, 1.0),
                              backgroundColor: AppTheme.border,
                              valueColor: AlwaysStoppedAnimation<Color>(barColor),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('Spent: ${data.fp.formatCurrency(spentAmt)}', style: TextStyle(color: barColor, fontSize: 12, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              if (pct >= 1.0)
                                const Text('⚠️ Over budget!', style: TextStyle(color: AppTheme.accentRed, fontSize: 12, fontWeight: FontWeight.w600))
                              else
                                Text('Left: ${data.fp.formatCurrency(budgetAmt - spentAmt)}', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // Budget tips
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Text('💡', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap any category to set a monthly budget. We\'ll alert you when you\'re close to the limit.',
                          style: TextStyle(color: AppTheme.accentBlue, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BudgetData {
  final Map<String, double> budget;
  final Map<String, double> spent;
  final double totalBudget;
  final double totalSpent;
  final FinanceProvider fp;

  _BudgetData({
    required this.budget,
    required this.spent,
    required this.totalBudget,
    required this.totalSpent,
    required this.fp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BudgetData &&
          totalBudget == other.totalBudget &&
          totalSpent == other.totalSpent &&
          budget.length == other.budget.length &&
          spent.length == other.spent.length;

  @override
  int get hashCode =>
      totalBudget.hashCode ^ totalSpent.hashCode ^ budget.length.hashCode ^ spent.length.hashCode;
}


