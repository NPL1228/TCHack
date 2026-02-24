import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../services/analytics_service.dart';

import '../theme/app_theme.dart';
import '../widgets/ai_insight_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  int _touchedIndex = -1;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _prevMonth() => setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _nextMonth() {
    final now  = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1);
    if (!next.isAfter(DateTime(now.year, now.month))) setState(() => _month = next);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Analytics'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.accent,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Trends'), Tab(text: 'Insights')],
        ),
      ),
      body: Column(
        children: [
          // ─ Month Navigator (only for Overview) ─
          ListenableBuilder(
            listenable: _tabs,
            builder: (_, __) {
              if (_tabs.index == 2) return const SizedBox.shrink(); // Insights tab – no month nav
              return Container(
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
              );
            },
          ),

          Expanded(
            child: Consumer<FinanceProvider>(
              builder: (ctx, fp, _) {
                final monthTxns = fp.normalize(fp.transactionsForMonth(_month.year, _month.month));
                final allTxns   = fp.normalize(fp.allTransactions);
                return TabBarView(
                  controller: _tabs,
                  children: [
                    _OverviewTab(
                      txns: monthTxns,
                      touchedIndex: _touchedIndex,
                      onTouch: (i) => setState(() => _touchedIndex = i),
                    ),
                    _TrendsTab(txns: allTxns),
                    _InsightsTab(fp: fp),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewData {
  final Map<String, double> byCategory;
  final double total;
  final List<MapEntry<String, double>> sorted;
  final List<Color> colors;

  _OverviewData(this.byCategory, this.total, this.sorted, this.colors);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _OverviewData && total == other.total && byCategory.length == other.byCategory.length;

  @override
  int get hashCode => total.hashCode ^ byCategory.length.hashCode;
}

// ── Overview Tab ──────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final List txns;
  final int touchedIndex;
  final Function(int) onTouch;

  const _OverviewTab({required this.txns, required this.touchedIndex, required this.onTouch});

  @override
  Widget build(BuildContext context) {
    return Selector<FinanceProvider, _OverviewData>(
      selector: (ctx, fp) {
        final byCategory = AnalyticsService.spendingByCategory(txns as dynamic);
        final total      = AnalyticsService.totalExpense(txns as dynamic);
        final sorted = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final colors = sorted.map((e) => AppTheme.categoryColors[e.key] ?? AppTheme.textSecondary).toList();
        return _OverviewData(byCategory, total, sorted, colors);
      },
      builder: (ctx, data, _) {
        final fp = ctx.watch<FinanceProvider>();

        if (data.byCategory.isEmpty) {
          return const Center(child: Text('No spending data for this month.', style: TextStyle(color: AppTheme.textSecondary)));
        }

        final sorted = data.sorted;
        final colors = data.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─ Summary row ─
          Row(
            children: [
              _SummaryCard(label: 'Total Spent', value: fp.formatCurrency(data.total), color: AppTheme.accentRed),
              const SizedBox(width: 12),
              _SummaryCard(
                label: 'Avg/Day',
                value: fp.formatCurrency(AnalyticsService.avgDailySpend(txns as dynamic)),
                color: AppTheme.accentBlue,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─ Pie Chart ─
          _Card(
            child: Column(
              children: [
                const Text('Spending by Category',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 240,
                  child: PieChart(PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    pieTouchData: PieTouchData(
                      touchCallback: (_, resp) {
                        onTouch(resp?.touchedSection?.touchedSectionIndex ?? -1);
                      },
                    ),
                    sections: sorted.asMap().entries.map((e) {
                      final i         = e.key;
                      final cat       = e.value;
                      final pct       = data.total > 0 ? (cat.value / data.total * 100) : 0.0;
                      final isTouched = i == touchedIndex;
                      // Labels inside if >=8%, outside via badgeWidget if <8%
                      final showInside = pct >= 8;
                      return PieChartSectionData(
                        value: cat.value,
                        color: colors[i],
                        radius: isTouched ? 82 : 72,
                        title: showInside ? '${pct.toStringAsFixed(0)}%' : '',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
                        ),
                        titlePositionPercentageOffset: 0.6,
                        // For small slices: show badge outside
                        badgeWidget: !showInside
                            ? _PctBadge(pct: pct, color: colors[i])
                            : null,
                        badgePositionPercentageOffset: 1.4,
                      );
                    }).toList(),
                  )),
                ),
                const SizedBox(height: 16),
                // Legend — category name only, no %
                Wrap(
                  spacing: 12, runSpacing: 8,
                  children: sorted.asMap().entries.map((e) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[e.key], shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(e.value.key,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─ Category breakdown list ─
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Category Breakdown',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 16),
                ...sorted.asMap().entries.map((e) {
                  final i         = e.key;
                  final cat       = e.value;
                  final pct       = data.total > 0 ? (cat.value / data.total * 100) : 0.0;
                  final color     = colors[i];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.category_rounded, color: color, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(e.value.key, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                                  const Spacer(),
                                  Text(fp.formatCurrency(e.value.value),
                                      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct.toDouble() / 100, // Fixed pct to match 0.0-1.0 range
                                  backgroundColor: AppTheme.border,
                                  valueColor: AlwaysStoppedAnimation<Color>(color),
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

class _TrendsData {
  final Map<String, double> monthly;
  final List<MapEntry<String, double>> entries;
  final double maxVal;

  _TrendsData(this.monthly, this.entries, this.maxVal);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TrendsData && maxVal == other.maxVal && monthly.length == other.monthly.length;

  @override
  int get hashCode => maxVal.hashCode ^ monthly.length.hashCode;
}

// ── Trends Tab ────────────────────────────────────────────────
class _TrendsTab extends StatelessWidget {
  final List txns;
  const _TrendsTab({required this.txns});

  @override
  Widget build(BuildContext context) {
    return Selector<FinanceProvider, _TrendsData>(
      selector: (ctx, fp) {
        final monthly = AnalyticsService.monthlySpending(txns as dynamic);
        final entries = monthly.entries.toList();
        final maxVal  = monthly.values.fold<double>(0, (m, v) => v > m ? v : m);
        return _TrendsData(monthly, entries, maxVal);
      },
      builder: (ctx, data, _) {
        final fp      = ctx.watch<FinanceProvider>();
        final monthly = data.monthly;
        final entries = data.entries;
        final maxVal  = data.maxVal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─ Bar chart – 6-month trend ─
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('6-Month Spending Trend',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  child: BarChart(BarChartData(
                    maxY: maxVal * 1.2,
                    gridData: FlGridData(
                      show: true,
                      getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border, strokeWidth: 1),
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= entries.length) return const SizedBox();
                            final parts = entries[i].key.split(' ');
                            return Text(parts[0], style: const TextStyle(color: AppTheme.textMuted, fontSize: 10));
                          },
                        ),
                      ),
                    ),
                    barGroups: entries.asMap().entries.map((e) => BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.value,
                          gradient: AppTheme.accentGradient,
                          width: 24,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    )).toList(),
                  )),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─ Monthly history table ─
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Monthly History',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 16),
                ...entries.reversed.take(6).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Text(e.key, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const Spacer(),
                      Text(fp.formatCurrency(e.value),
                          style: TextStyle(
                            color: e.value > 0 ? AppTheme.textPrimary : AppTheme.textMuted,
                            fontWeight: FontWeight.w600, fontSize: 14,
                          )),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

// ── Insights Tab ──────────────────────────────────────────────
String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24)   return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class _InsightsTab extends StatelessWidget {
  final FinanceProvider fp;
  const _InsightsTab({required this.fp});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─ Header with Refresh button ─
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.accent.withValues(alpha: 0.12), AppTheme.surfaceCard],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Spending Insights', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                          Text('Value maximization · Price comparisons', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (fp.isLoadingInsights)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                    else
                      GestureDetector(
                        onTap: () => fp.refreshInsights(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded, color: AppTheme.accent, size: 14),
                              SizedBox(width: 4),
                              Text('Refresh', style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (fp.insightsGeneratedAt != null) ...[  
                  const SizedBox(height: 6),
                  Text(
                    'Last updated: ${_timeAgo(fp.insightsGeneratedAt!)}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─ Insights list ─
          if (fp.isLoadingInsights)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppTheme.accent),
                  SizedBox(height: 16),
                  Text('Analysing your spending patterns...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ))
          else if (fp.aiInsights.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Column(
                children: [
                  Text('✨', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 12),
                  Text('No insights yet', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                  SizedBox(height: 6),
                  Text('Tap Refresh to get AI-powered spending analysis,\nprice comparisons, and value tips.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            )
          else
            ...fp.aiInsights.map((insight) => AiInsightCard(insight: insight)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.border),
    ),
    child: child,
  );
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );
}

/// Small pill badge shown outside pie chart for slices < 8%
class _PctBadge extends StatelessWidget {
  final double pct;
  final Color color;
  const _PctBadge({required this.pct, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
    ),
    child: Text(
      '${pct.toStringAsFixed(0)}%',
      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
    ),
  );
}
