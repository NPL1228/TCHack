import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/account.dart';
import '../services/gemini_service.dart';
import '../services/analytics_service.dart';
import '../services/currency_service.dart';
import '../services/excel_service.dart';
import '../services/settings_service.dart';
import '../services/subcategory_service.dart';
import '../services/backup_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class FinanceProvider extends ChangeNotifier {
  static const String _txnBoxName     = 'transactions';
  static const String _budgetBoxName  = 'budgets';
  static const String _accountBoxName = 'accounts';
  static const String _insightBoxName = 'ai_insights';

  late Box<Transaction> _txnBox;
  late Box<Budget>      _budgetBox;
  late Box<Account>     _accountBox;
  late Box<dynamic>     _insightBox;
  final _uuid = const Uuid();

  List<String> _aiInsights = [];
  bool _isLoadingInsights = false;
  DateTime? _insightsGeneratedAt;
  DateTime? get insightsGeneratedAt => _insightsGeneratedAt;

  // ── Currency State ───────────────────────────────────────────
  String _mainCurrency = 'MYR';
  String get mainCurrency => _mainCurrency;

  // Caches
  List<Transaction>? _cachedTxns;
  Map<String, double> _rates = {};



  Future<void> setMainCurrency(String currency) async {
    _mainCurrency = currency;
    notifyListeners();
  }

  Future<void> fetchExchangeRates() async {
    _rates = await CurrencyService.fetchRates('MYR');
    notifyListeners();
  }

  double convertAmount(double amount, String fromCurrency, String toCurrency) {
    if (fromCurrency == toCurrency) return amount;
    final from = fromCurrency == 'RM' ? 'MYR' : fromCurrency;
    final to   = toCurrency == 'RM' ? 'MYR' : toCurrency;
    if (from == to) return amount;

    final rateFrom = _rates[from] ?? 1.0;
    final rateTo   = _rates[to] ?? 1.0;
    return (amount / rateFrom) * rateTo;
  }

  String getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD': return r'$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      case 'SGD': return r'S$';
      case 'RM':
      case 'MYR': return 'RM';
      default: return currency;
    }
  }

  String formatCurrency(double amount, {String? currency}) {
    final cur = currency ?? _mainCurrency;
    final code = cur == 'RM' ? 'MYR' : cur;
    final sym = getCurrencySymbol(code);
    final fmt = NumberFormat('#,##0.00');
    return '$sym ${fmt.format(amount)}';
  }

  // ── Transaction Getters ──────────────────────────────────────
  List<Transaction> get allTransactions {
    if (_cachedTxns == null) {
      _cachedTxns = _txnBox.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    }
    return _cachedTxns!;
  }

  List<Transaction> get thisMonthTransactions {
    final now = DateTime.now();
    return allTransactions
        .where((t) => t.date.month == now.month && t.date.year == now.year)
        .toList();
  }

  List<Transaction> normalize(Iterable<Transaction> txns) {
    return txns.map((t) => _normalizeTransaction(t)).toList();
  }

  Transaction _normalizeTransaction(Transaction t) {
    if (t.currency == _mainCurrency) return t;
    return Transaction(
      id: t.id,
      title: t.title,
      storeName: t.storeName,
      amount: convertAmount(t.amount, t.currency, _mainCurrency),
      category: t.category,
      date: t.date,
      currency: _mainCurrency,
      isExpense: t.isExpense,
      notes: t.notes,
      items: t.items,
      receiptImagePath: t.receiptImagePath,
      accountId: t.accountId,
    );
  }

  List<Transaction> get recentTransactions =>
      allTransactions.take(10).toList();

  // ── Account Getters ──────────────────────────────────────────
  List<Account> get allAccounts => _accountBox.values.toList();

  Account? accountById(String id) => _accountBox.get(id);

  double get totalBalance =>
      allAccounts.fold(0, (sum, a) => sum + convertAmount(a.balance, a.currency, _mainCurrency));

  // ── Budget Getters ───────────────────────────────────────────
  List<Budget> get budgets => _budgetBox.values.toList();

  Map<String, double> get budgetMap {
    final now = DateTime.now();
    return {
      for (final b in budgets)
        if (b.month == now.month && b.year == now.year)
          b.category: b.monthlyLimit,
    };
  }

  // ── Analytics Getters ────────────────────────────────────────
  List<String> get aiInsights => _aiInsights;
  bool get isLoadingInsights => _isLoadingInsights;

  double get totalExpense =>
      thisMonthTransactions.where((t) => t.isExpense).fold(0.0, (sum, t) => sum + convertAmount(t.amount, t.currency, _mainCurrency));
  double get totalIncome =>
      thisMonthTransactions.where((t) => !t.isExpense).fold(0.0, (sum, t) => sum + convertAmount(t.amount, t.currency, _mainCurrency));
  double get balance => totalIncome - totalExpense;
  String? get topCategory =>
      AnalyticsService.topCategory(thisMonthTransactions);
  double get avgDailySpend =>
      AnalyticsService.avgDailySpend(thisMonthTransactions);

  // ── Initialization ───────────────────────────────────────────
  Future<void> init() async {
    _txnBox    = Hive.box<Transaction>(_txnBoxName);
    _budgetBox = Hive.box<Budget>(_budgetBoxName);
    _accountBox = Hive.box<Account>(_accountBoxName);
    _insightBox = Hive.box<dynamic>(_insightBoxName);

    // Restore persisted insights
    final saved = _insightBox.get('insights');
    if (saved != null) _aiInsights = List<String>.from(saved as List);
    final ts = _insightBox.get('generated_at') as int?;
    if (ts != null) _insightsGeneratedAt = DateTime.fromMillisecondsSinceEpoch(ts);

    if (_accountBox.isEmpty) await _loadSampleAccounts();
    if (_txnBox.isEmpty) await _loadSampleData();
    // Fetch live currency rates in background
    fetchExchangeRates();
    // Process any overdue recurring transactions
    processRecurring();
    // Auto-backup if due
    checkAndRunAutoBackup();

    _cachedTxns = null; // Invalidate any premature caching performed while yielding above
    notifyListeners();
  }

  // ── Account CRUD ─────────────────────────────────────────────
  Future<Account> addAccount({
    required String name,
    required String type,
    required double balance,
    required String colorHex,
    required String iconName,
    String currency = 'MYR',
  }) async {
    final a = Account(
      id:       _uuid.v4(),
      name:     name,
      type:     type,
      balance:  balance,
      colorHex: colorHex,
      iconName: iconName,
      currency: currency,
    );
    await _accountBox.put(a.id, a);
    notifyListeners();
    return a;
  }

  Future<void> updateAccount(Account a) async {
    await _accountBox.put(a.id, a);
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    await _accountBox.delete(id);
    notifyListeners();
  }

  /// Adjust an account's balance by [delta] (positive = add, negative = deduct).
  Future<void> _adjustBalance(String? accountId, double delta) async {
    if (accountId == null) return;
    final acc = _accountBox.get(accountId);
    if (acc == null) return;
    acc.balance += delta;
    await _accountBox.put(accountId, acc);
  }

  // ── Transactions CRUD ────────────────────────────────────────
  Future<Transaction> addTransaction({
    required String title,
    required String storeName,
    required double amount,
    required String category,
    DateTime? date,
    String currency = 'RM',
    bool isExpense = true,
    String? notes,
    List<String>? items,
    String? receiptImagePath,
    String? accountId,
    bool isRecurring = false,
    String? recurringPeriod,
    DateTime? recurringNextDate,
    String? subcategory,
  }) async {
    final t = Transaction(
      id:               _uuid.v4(),
      title:            title,
      storeName:        storeName,
      amount:           amount,
      category:         category,
      date:             date ?? DateTime.now(),
      currency:         currency,
      isExpense:        isExpense,
      notes:            notes,
      items:            items,
      receiptImagePath: receiptImagePath,
      accountId:        accountId,
      isRecurring:      isRecurring,
      recurringPeriod:  recurringPeriod,
      recurringNextDate: recurringNextDate,
      subcategory:      subcategory,
    );
    await _txnBox.put(t.id, t);
    _cachedTxns = null; // Invalidate cache
    // Adjust account balance
    await _adjustBalance(accountId, isExpense ? -amount : amount);
    notifyListeners();
    return t;
  }

  Future<void> updateTransaction(Transaction t) async {
    await _txnBox.put(t.id, t);
    _cachedTxns = null; // Invalidate cache
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    final t = _txnBox.get(id);
    if (t != null) {
      // Reverse the balance effect (but not for transfers — handled by addTransfer)
      if (!t.isTransfer) {
        await _adjustBalance(t.accountId, t.isExpense ? t.amount : -t.amount);
      }
    }
    await _txnBox.delete(id);
    _cachedTxns = null; // Invalidate cache
    notifyListeners();
  }

  // ── Transfers ─────────────────────────────────────────────────
  Future<void> addTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String? currency,
    DateTime? date,
    String? notes,
  }) async {
    final cur  = currency ?? _mainCurrency;
    final when = date ?? DateTime.now();
    final fromAcc = _accountBox.get(fromAccountId);
    final toAcc   = _accountBox.get(toAccountId);
    if (fromAcc == null || toAcc == null) return;

    // Amount in destination currency
    final amountTo = convertAmount(amount, cur, toAcc.currency);

    final outId = _uuid.v4();
    final inId  = _uuid.v4();

    final outTxn = Transaction(
      id: outId, title: 'Transfer to ${toAcc.name}', storeName: '',
      amount: amount, category: 'Transfer', date: when, currency: cur,
      isExpense: true, notes: notes, accountId: fromAccountId,
      isTransfer: true, transferToAccountId: toAccountId,
    );
    final inTxn = Transaction(
      id: inId, title: 'Transfer from ${fromAcc.name}', storeName: '',
      amount: amountTo, category: 'Transfer', date: when, currency: toAcc.currency,
      isExpense: false, notes: notes, accountId: toAccountId,
      isTransfer: true, transferToAccountId: fromAccountId,
    );

    await _txnBox.put(outTxn.id, outTxn);
    await _txnBox.put(inTxn.id, inTxn);
    await _adjustBalance(fromAccountId, -amount);
    await _adjustBalance(toAccountId, amountTo);
    notifyListeners();
  }

  // ── Budget CRUD ──────────────────────────────────────────────
  Future<void> setBudget(String category, double limit) async {
    final now = DateTime.now();
    final key = '${category}_${now.month}_${now.year}';
    final existing = _budgetBox.get(key);
    if (existing != null) {
      existing.monthlyLimit = limit;
      await existing.save();
    } else {
      await _budgetBox.put(
        key,
        Budget(
          category: category,
          monthlyLimit: limit,
          month: now.month,
          year: now.year,
        ),
      );
    }
    notifyListeners();
  }

  // ── AI Insights ───────────────────────────────────────────────
  Future<void> refreshInsights() async {
    _isLoadingInsights = true;
    notifyListeners();
    try {
      _aiInsights = await GeminiService.generateInsights(thisMonthTransactions);
    } catch (_) {
      _aiInsights = [
        '🍔 Food & Dining is your top spending category this month.',
        '💡 You could save RM 150/month by reducing dining out by 2 times per week.',
        '📊 Your spending is 12% higher than last month.',
      ];
    }
    _insightsGeneratedAt = DateTime.now();
    // Persist insights to Hive
    await _insightBox.put('insights', _aiInsights);
    await _insightBox.put('generated_at', _insightsGeneratedAt!.millisecondsSinceEpoch);
    _isLoadingInsights = false;
    notifyListeners();
  }

  // ── Excel Export ─────────────────────────────────────────────
  /// Export an analysis .xlsx for the given months.
  Future<String?> exportTransactionsExcel(List<({int year, int month})> months) async {
    return ExcelService.exportAnalysis(
      months: months,
      allTransactions: allTransactions,
      formatCurrency: formatCurrency,
    );
  }

  // ── Batch Transaction Ops ─────────────────────────────────────
  /// Delete multiple transactions at once and reverse their account balances.
  Future<void> batchDeleteTransactions(List<String> ids) async {
    for (final id in ids) {
      final t = _txnBox.get(id);
      if (t != null && !t.isTransfer) {
        await _adjustBalance(t.accountId, t.isExpense ? t.amount : -t.amount);
      }
      await _txnBox.delete(id);
    }
    _cachedTxns = null;
    notifyListeners();
  }

  /// Change the date on multiple transactions.
  Future<void> batchUpdateDate(List<String> ids, DateTime newDate) async {
    for (final id in ids) {
      final t = _txnBox.get(id);
      if (t == null) continue;
      t.date = newDate;
      await _txnBox.put(id, t);
    }
    _cachedTxns = null;
    notifyListeners();
  }

  // ── JSON Full Backup ──────────────────────────────────────────
  Future<String> exportFullBackup() async {
    return BackupService.exportBackup(
      accounts: allAccounts,
      transactions: allTransactions,
      budgets: budgets,
    );
  }

  Future<void> restoreFromBackup(String jsonContent) async {
    final parsed = BackupService.importBackup(jsonContent);

    // 1. Wipe existing data
    await _accountBox.clear();
    await _txnBox.clear();
    await _budgetBox.clear();

    // 2. Insert new data exactly as defined
    await _accountBox.putAll({ for (final a in parsed['accounts'] as List<Account>) a.id: a });
    await _txnBox.putAll({ for (final t in parsed['transactions'] as List<Transaction>) t.id: t });
    await _budgetBox.putAll({ for (final b in parsed['budgets'] as List<Budget>) '${b.category}_${b.month}_${b.year}': b });

    _cachedTxns = null;
    notifyListeners();
  }

  // ── Filter helpers ────────────────────────────────────────────
  List<Transaction> filterTransactions({
    List<String>? categories,
    List<String>? accountIds,
    DateTime? from,
    DateTime? to,
    String? query,
  }) {
    return allTransactions.where((t) {
      if (categories != null && categories.isNotEmpty && !categories.contains(t.category))  return false;
      if (accountIds != null && accountIds.isNotEmpty && !accountIds.contains(t.accountId)) return false;
      if (from != null && t.date.isBefore(from)) return false;
      if (to   != null && t.date.isAfter(to))   return false;
      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        if (!t.title.toLowerCase().contains(q) &&
            !t.storeName.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  /// Group transactions by date (day only).
  Map<DateTime, List<Transaction>> groupByDate(List<Transaction> txns) {
    final Map<DateTime, List<Transaction>> result = {};
    for (final t in txns) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      result.putIfAbsent(key, () => []).add(t);
    }
    return Map.fromEntries(
      result.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  /// Transactions for a specific month+year (with optional account/category filter).
  List<Transaction> transactionsForMonth(int year, int month, {
    List<String>? categories,
    List<String>? accountIds,
    String? query,
  }) {
    return allTransactions.where((t) {
      if (t.date.year != year || t.date.month != month) return false;
      if (categories != null && categories.isNotEmpty && !categories.contains(t.category))  return false;
      if (accountIds != null && accountIds.isNotEmpty && !accountIds.contains(t.accountId)) return false;
      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        if (!t.title.toLowerCase().contains(q) &&
            !t.storeName.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  // ── Sample Data ───────────────────────────────────────────────
  Future<void> _loadSampleAccounts() async {
    final samples = [
      ('Maybank Savings', 'Bank',     3200.00, '#3B82F6', 'account_balance'),
      ('Touch \'n Go',    'E-Wallet',  450.00, '#8B5CF6', 'account_balance_wallet'),
      ('Wallet',          'Cash',       80.00, '#10B981', 'payments'),
      ('CIMB Credit',     'Card',        0.00, '#F59E0B', 'credit_card'),
    ];
    final Map<String, Account> newAccounts = {};
    for (final s in samples) {
      final a = Account(
        id: _uuid.v4(), name: s.$1, type: s.$2,
        balance: s.$3, colorHex: s.$4, iconName: s.$5,
      );
      newAccounts[a.id] = a;
    }
    await _accountBox.putAll(newAccounts);
  }

  Future<void> _loadSampleData() async {
    final now     = DateTime.now();
    // Use the first account (Maybank) for sample transactions
    final acctId  = _accountBox.values.isNotEmpty
        ? _accountBox.values.first.id
        : null;

    final samples = [
      ('Lunch at McDonald\'s', 'McDonald\'s Sunway', 22.90,  'Food & Dining',  now.subtract(const Duration(days: 1)),  'RM', true),
      ('Groceries',            'Jaya Grocer',         87.50,  'Groceries',       now.subtract(const Duration(days: 2)),  'RM', true),
      ('Grab to KLCC',         'Grab',                18.00,  'Transport',       now.subtract(const Duration(days: 3)),  'RM', true),
      ('Netflix Subscription', 'Netflix',             54.90,  'Subscriptions',   now.subtract(const Duration(days: 5)),  'RM', true),
      ('GSC Movie Ticket',     'GSC Pavilion',        28.00,  'Entertainment',   now.subtract(const Duration(days: 6)),  'RM', true),
      ('Pharmacy',             'Guardian Pharmacy',   35.20,  'Health',          now.subtract(const Duration(days: 7)),  'RM', true),
      ('Monthly Salary',       'Employer',          4500.00,  'Other',           now.subtract(const Duration(days: 10)), 'RM', false),
      ('Dinner at Nando\'s',   'Nando\'s',            65.00,  'Food & Dining',   now.subtract(const Duration(days: 4)),  'RM', true),
      ('Shopee Purchase',      'Shopee',              45.00,  'Shopping',        now.subtract(const Duration(days: 8)),  'RM', true),
      ('Unifi Monthly',        'Unifi',              109.00,  'Utilities',       now.subtract(const Duration(days: 9)),  'RM', true),
    ];

    final Map<String, Transaction> newTxns = {};
    for (final s in samples) {
      final t = Transaction(
        id: _uuid.v4(),
        title: s.$1, storeName: s.$2, amount: s.$3,
        category: s.$4, date: s.$5,
        currency: s.$6, isExpense: s.$7,
        accountId: acctId,
      );
      newTxns[t.id] = t;
    }
    await _txnBox.putAll(newTxns);
    notifyListeners();
  }

  // ── Recurring Transactions ─────────────────────────────────────
  /// All recurring template transactions (source records with isRecurring=true and a recurringPeriod set).
  List<Transaction> get recurringTemplates =>
      _txnBox.values.where((t) => t.isRecurring && t.recurringPeriod != null).toList()
        ..sort((a, b) => a.title.compareTo(b.title));

  Future<void> updateRecurringTemplate(Transaction t) async {
    await _txnBox.put(t.id, t);
    _cachedTxns = null;
    notifyListeners();
  }

  Future<void> deleteRecurringTemplate(String id) async {
    final t = _txnBox.get(id);
    if (t != null && !t.isTransfer) {
      await _adjustBalance(t.accountId, t.isExpense ? t.amount : -t.amount);
    }
    await _txnBox.delete(id);
    _cachedTxns = null;
    notifyListeners();
  }

  Future<void> processRecurring() async {
    if (!SettingsService.recurringEnabled) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final toCreate = <Transaction>[];

    for (final t in _txnBox.values.where((t) => t.isRecurring && t.recurringNextDate != null)) {
      var next = DateTime(t.recurringNextDate!.year, t.recurringNextDate!.month, t.recurringNextDate!.day);
      while (!next.isAfter(today)) {
        toCreate.add(Transaction(
          id: _uuid.v4(),
          title: t.title, storeName: t.storeName, amount: t.amount,
          category: t.category, date: next, currency: t.currency,
          isExpense: t.isExpense, notes: t.notes, accountId: t.accountId,
          subcategory: t.subcategory,
          isRecurring: true,
          recurringPeriod: t.recurringPeriod,
        ));
        await _adjustBalance(t.accountId, t.isExpense ? -t.amount : t.amount);
        next = _advanceDate(next, t.recurringPeriod!);
      }
      // Update the template's next date
      t.recurringNextDate = next;
      await t.save();
    }
    if (toCreate.isNotEmpty) {
      await _txnBox.putAll({ for (final x in toCreate) x.id: x });
      _cachedTxns = null; // Invalidate cache
      notifyListeners();
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

  // ── Auto Backup ────────────────────────────────────────────────
  Future<void> checkAndRunAutoBackup() async {
    if (!SettingsService.backupEnabled) return;
    if (!SettingsService.isBackupDue)   return;
    try {
      final jsonStr = BackupService.exportBackup(
        accounts: allAccounts,
        transactions: allTransactions,
        budgets: budgets,
      );
      final dir  = await getApplicationDocumentsDirectory();
      final now  = DateTime.now();
      final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final file = File('${dir.path}/auto_backup_$timestamp.json');
      await file.writeAsString(jsonStr);
      await SettingsService.setLastBackupAt(now);
    } catch (_) {/* silent */}
  }

  static Future<void> openBoxes() async {
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BudgetAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(AccountAdapter());
    await Hive.openBox<Transaction>(_txnBoxName);
    await Hive.openBox<Budget>(_budgetBoxName);
    await Hive.openBox<Account>(_accountBoxName);
    await Hive.openBox<dynamic>(_insightBoxName);
    await SettingsService.open();
    await SubcategoryService.open();
  }
}
