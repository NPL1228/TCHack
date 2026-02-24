import '../models/transaction.dart';

class AnalyticsService {
  // ── Spending by category ────────────────────────────────────
  static Map<String, double> spendingByCategory(List<Transaction> txns) {
    final Map<String, double> result = {};
    for (final t in txns.where((t) => t.isExpense)) {
      result[t.category] = (result[t.category] ?? 0) + t.amount;
    }
    return result;
  }

  // ── Total expense / income ──────────────────────────────────
  static double totalExpense(List<Transaction> txns) =>
      txns.where((t) => t.isExpense).fold(0, (sum, t) => sum + t.amount);

  static double totalIncome(List<Transaction> txns) =>
      txns.where((t) => !t.isExpense).fold(0, (sum, t) => sum + t.amount);

  // ── Daily spending (last N days) ────────────────────────────
  static Map<DateTime, double> dailySpending(List<Transaction> txns, {int days = 7}) {
    final Map<DateTime, double> result = {};
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      result[day] = 0;
    }
    for (final t in txns.where((t) => t.isExpense)) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (result.containsKey(day)) {
        result[day] = (result[day] ?? 0) + t.amount;
      }
    }
    return result;
  }

  // ── Monthly spending (last 6 months) ───────────────────────
  static Map<String, double> monthlySpending(List<Transaction> txns) {
    final Map<String, double> result = {};
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      result['${months[m.month - 1]} ${m.year}'] = 0;
    }
    for (final t in txns.where((t) => t.isExpense)) {
      final key = '${months[t.date.month - 1]} ${t.date.year}';
      if (result.containsKey(key)) {
        result[key] = (result[key] ?? 0) + t.amount;
      }
    }
    return result;
  }

  // ── Weekend vs weekday spending ────────────────────────────
  static Map<String, double> weekendVsWeekday(List<Transaction> txns) {
    double weekend = 0, weekday = 0;
    for (final t in txns.where((t) => t.isExpense)) {
      final w = t.date.weekday;
      if (w == DateTime.saturday || w == DateTime.sunday) {
        weekend += t.amount;
      } else {
        weekday += t.amount;
      }
    }
    return {'Weekend': weekend, 'Weekday': weekday};
  }

  // ── Budget utilization ──────────────────────────────────────
  static Map<String, double> budgetUtilization(
    List<Transaction> txns,
    Map<String, double> budgets,
    int month,
    int year,
  ) {
    final monthTxns = txns.where(
      (t) => t.isExpense && t.date.month == month && t.date.year == year,
    );
    final Map<String, double> spent = {};
    for (final t in monthTxns) {
      spent[t.category] = (spent[t.category] ?? 0) + t.amount;
    }
    final Map<String, double> result = {};
    for (final entry in budgets.entries) {
      final s = spent[entry.key] ?? 0;
      result[entry.key] = entry.value > 0 ? (s / entry.value).clamp(0.0, 2.0) : 0;
    }
    return result;
  }

  // ── Top spending category ───────────────────────────────────
  static String? topCategory(List<Transaction> txns) {
    final byCategory = spendingByCategory(txns);
    if (byCategory.isEmpty) return null;
    return byCategory.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }




  // ── Recurring transaction detection ────────────────────────
  static List<Transaction> detectRecurring(List<Transaction> txns) {
    final Map<String, List<Transaction>> byStore = {};
    for (final t in txns) {
      byStore.putIfAbsent(t.storeName, () => []).add(t);
    }
    final List<Transaction> recurring = [];
    for (final group in byStore.values) {
      if (group.length >= 2) recurring.addAll(group);
    }
    return recurring;
  }

  // ── Avg daily spend ────────────────────────────────────────
  static double avgDailySpend(List<Transaction> txns) {
    if (txns.isEmpty) return 0;
    final expenses = txns.where((t) => t.isExpense).toList();
    if (expenses.isEmpty) return 0;
    final dates = expenses.map((t) => DateTime(t.date.year, t.date.month, t.date.day)).toSet();
    return totalExpense(expenses) / dates.length;
  }

  // ── MoM change for a category ───────────────────────────────
  static double monthOverMonthChange(List<Transaction> txns, String category) {
    final now = DateTime.now();
    double thisMonth = 0, lastMonth = 0;
    for (final t in txns.where((t) => t.isExpense && t.category == category)) {
      if (t.date.month == now.month && t.date.year == now.year) thisMonth += t.amount;
      if (t.date.month == now.month - 1 || (now.month == 1 && t.date.month == 12)) {
        lastMonth += t.amount;
      }
    }
    if (lastMonth == 0) return 0;
    return ((thisMonth - lastMonth) / lastMonth) * 100;
  }
}
