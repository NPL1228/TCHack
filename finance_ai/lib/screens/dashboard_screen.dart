import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'scan_receipt_screen.dart';
import 'add_transaction_screen.dart';
import 'analytics_screen.dart';
import 'transactions_screen.dart';
import 'accounts_screen.dart';
import 'more_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    TransactionsScreen(),
    AccountsScreen(),
    AnalyticsScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Safety check for hot-reload state restoration
    if (_selectedIndex >= _pages.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          backgroundColor: AppTheme.surface,
          selectedItemColor: AppTheme.accent,
          unselectedItemColor: AppTheme.textMuted,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded),          label: 'Transactions'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Accounts'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded),              label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz_rounded),             label: 'More'),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Option helpers used by TransactionsScreen add sheet
// ──────────────────────────────────────────────────────────────
class OptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const OptionTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Helper – show "Add transaction" picker modal (used by TransactionsScreen)
// ──────────────────────────────────────────────────────────────
void showAddTransactionOptions(BuildContext ctx) {
  showModalBottomSheet(
    context: ctx,
    backgroundColor: AppTheme.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          const Text('Add Transaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 20),
          OptionTile(
            icon: Icons.document_scanner_rounded,
            color: AppTheme.accent,
            title: 'Scan Receipt',
            subtitle: 'Use AI to extract from photo',
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ScanReceiptScreen()));
            },
          ),
          const SizedBox(height: 12),
          OptionTile(
            icon: Icons.edit_note_rounded,
            color: AppTheme.accentBlue,
            title: 'Add Manually',
            subtitle: 'Enter transaction details (inc. Transfer)',
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(ctx, MaterialPageRoute(builder: (_) => const AddTransactionScreen()));
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}


