import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;

  const TransactionCard({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final fp      = context.watch<FinanceProvider>();
    final t       = transaction;
    final isXfer  = t.isTransfer;
    final color   = isXfer ? AppTheme.accentBlue : (AppTheme.categoryColors[t.category] ?? AppTheme.textSecondary);
    final icon    = isXfer ? '↔' : (AppTheme.categoryIcons[t.category] ?? '📦');
    final dateFmt = DateFormat('dd MMM');

    // Resolve account name
    final accountName = fp.allAccounts.where((a) => a.id == t.accountId).firstOrNull?.name ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),

          // Title & Store
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(t.category, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
                    ),
                    if (t.subcategory != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(t.subcategory!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, size: 10, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(accountName, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Text(dateFmt.format(t.date), style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${t.isExpense ? '-' : '+'}${fp.formatCurrency(t.amount, currency: t.currency)}',
                style: TextStyle(
                  color: isXfer ? AppTheme.accentBlue : (t.isExpense ? AppTheme.accentRed : AppTheme.accent),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (isXfer)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Transfer', style: TextStyle(color: AppTheme.accentBlue, fontSize: 9, fontWeight: FontWeight.w700)),
                )
              else if (t.carbonFootprint != null && t.carbonFootprint! > 0)
                Text(
                  '🌱 ${t.carbonFootprint!.toStringAsFixed(1)} kg',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
