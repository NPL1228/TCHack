import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/api_keys.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';

class GeminiService {
  static GenerativeModel? _model;
  static GenerativeModel? _visionModel;
  static ChatSession? _chatSession;

  static bool get hasApiKey =>
      ApiKeys.gemini.isNotEmpty && ApiKeys.gemini != '[GCP_API_KEY]';

  static void _init() {
    if (_model != null) return;
    _model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: ApiKeys.gemini,
    );
    _visionModel = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: ApiKeys.gemini,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // A. Receipt OCR – extract structured data from image
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> analyzeReceipt(File imageFile) async {
    if (!hasApiKey) return _mockReceiptData();

    try {
      _init();
      final imageBytes = await imageFile.readAsBytes();
      final prompt = '''
You are a receipt OCR and data extraction expert.
Analyze this receipt image and extract the following information.
Return ONLY valid JSON (no markdown, no explanation) in this exact format:
{
  "store_name": "Store name",
  "date": "YYYY-MM-DD",
  "total_amount": 0.00,
  "currency": "RM",
  "category": "One of: Food & Dining, Groceries, Transport, Entertainment, Utilities, Shopping, Health, Subscriptions, Education, Travel, Personal Care, Other",
  "items": ["Item 1 - RM X.XX", "Item 2 - RM X.XX"],
  "confidence": 0.95
}
If you cannot determine a field, use null. Use MYR/RM as default currency if not shown.
''';

      final response = await _visionModel!.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ]);

      final text = response.text ?? '';
      final jsonStr = _extractJson(text);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      return _mockReceiptData();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // B. Categorize a transaction by description / store name
  // ─────────────────────────────────────────────────────────────
  static Future<String> categorizeTransaction(String title, String store) async {
    if (!hasApiKey) return _guessCategory(title, store);

    try {
      _init();
      final categories = AppTheme.categories.join(', ');
      final prompt = '''
Classify this transaction into exactly one category.
Transaction: "$title" at store "$store"
Available categories: $categories
Return ONLY the category name, nothing else.
''';
      final response = await _model!.generateContent([Content.text(prompt)]);
      final result = response.text?.trim() ?? 'Other';
      return AppTheme.categories.contains(result) ? result : 'Other';
    } catch (_) {
      return _guessCategory(title, store);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // C. AI Financial Advisor Chat
  // ─────────────────────────────────────────────────────────────
  static Future<String> chat(
    String userMessage,
    List<Transaction> recentTransactions,
  ) async {
    if (!hasApiKey) return _mockChatResponse(userMessage);

    try {
      _init();

      if (_chatSession == null) {
        final spendingSummary = _buildSpendingContext(recentTransactions);
        _chatSession = _model!.startChat(history: [
          Content.text('''
You are AiLedge, a friendly and smart personal finance advisor.
The user's recent spending summary (last 30 days):
$spendingSummary
Currency: Malaysian Ringgit (RM).
Provide concise, actionable advice. Use bullet points when listing tips.
Keep responses under 200 words unless asked for more detail.
'''),
          Content.model([TextPart('Hello! I\'m AiLedge, your personal finance advisor. I\'ve reviewed your recent spending. How can I help you today?')]),
        ]);
      }

      final response = await _chatSession!.sendMessage(Content.text(userMessage));
      return response.text ?? 'Sorry, I could not process that. Please try again.';
    } catch (e) {
      return _mockChatResponse(userMessage);
    }
  }

  static void resetChat() => _chatSession = null;

  // ─────────────────────────────────────────────────────────────
  // D. Generate AI Spending Insights
  // ─────────────────────────────────────────────────────────────
  static Future<List<String>> generateInsights(List<Transaction> transactions) async {
    if (!hasApiKey || transactions.isEmpty) return _mockInsights();

    try {
      _init();
      final summary = _buildSpendingContext(transactions);
      final storeData = _buildStoreContext(transactions);
      final prompt = '''
Analyze this spending data and generate exactly 5 short, sharp financial insights.
Focus on: value maximization, price comparisons between stores, spending patterns, and finding the best deals.
Each insight must be 1 line (max 12 words). Be specific with numbers and store names where possible.
Start each with a relevant emoji. Be bold and specific.
Examples:
 - "🏪 Jaya Grocer is 30% cheaper than GrabFood for groceries"
 - "🍔 Food & Dining is 42% of total spending"
 - "💡 Switch 2 meals/week to cooking — saves est. RM 120/mo"
 - "🔁 3 subscriptions detected — review if all are used"
Format as JSON array: ["insight1","insight2","insight3","insight4","insight5"]

Spending by category:
$summary

Store breakdown (store: total spent):
$storeData
''';
      final response = await _model!.generateContent([Content.text(prompt)]);
      final text     = response.text ?? '';
      final jsonStr  = _extractJson(text);
      final List<dynamic> insights = jsonDecode(jsonStr);
      return insights.cast<String>();
    } catch (_) {
      return _mockInsights();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // E. Grocery Store Suggestions
  // ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> generateGrocerySuggestions(
    List<String> items,
    List<Transaction> transactions,
  ) async {
    if (items.isEmpty) return [];
    if (!hasApiKey || transactions.isEmpty) return _mockGrocerySuggestions(items);

    try {
      _init();
      final storeData = _buildStoreContext(transactions);
      final itemList  = items.map((e) => '- $e').join('\n');
      final prompt = '''
The user wants to buy these grocery items:
$itemList

Based on their past shopping history at these stores (store: total spent):
$storeData

For each item, suggest the 2-3 best places to buy it, with estimated price and a value rating (Budget/Mid/Premium).
Use the store history to rank by value. If a store isn't in history, you may suggest popular Malaysian supermarkets (Jaya Grocer, Lotus's, AEON, Mydin, Giant, 99 Speedmart).

Return ONLY valid JSON array, no markdown, in this format:
[
  {
    "item": "Milk 1L",
    "suggestions": [
      {"store": "Lotus's", "est_price": "RM 6.50", "rating": "Budget", "note": "Cheapest option"},
      {"store": "Jaya Grocer", "est_price": "RM 8.90", "rating": "Mid", "note": "Better quality"}
    ]
  }
]
''';
      final response = await _model!.generateContent([Content.text(prompt)]);
      final text     = response.text ?? '';
      final jsonStr  = _extractJson(text);
      final List<dynamic> result = jsonDecode(jsonStr);
      return result.cast<Map<String, dynamic>>();
    } catch (_) {
      return _mockGrocerySuggestions(items);
    }
  }


  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────
  static String _extractJson(String text) {
    final startBrace  = text.indexOf('{');
    final startBracket = text.indexOf('[');
    if (startBrace == -1 && startBracket == -1) return '{}';

    int start;
    String endChar;
    if (startBrace == -1) {
      start = startBracket;
      endChar = ']';
    } else if (startBracket == -1) {
      start = startBrace;
      endChar = '}';
    } else {
      start = startBrace < startBracket ? startBrace : startBracket;
      endChar = start == startBrace ? '}' : ']';
    }

    final end = text.lastIndexOf(endChar);
    if (end == -1) return '{}';
    return text.substring(start, end + 1);
  }

  static String _buildSpendingContext(List<Transaction> txns) {
    final Map<String, double> byCategory = {};
    double total = 0;
    for (final t in txns) {
      if (t.isExpense) {
        byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
        total += t.amount;
      }
    }
    final lines = byCategory.entries
        .map((e) => '  ${e.key}: RM${e.value.toStringAsFixed(2)}')
        .join('\n');
    return 'Total spent: RM${total.toStringAsFixed(2)}\nBy category:\n$lines\nTransactions: ${txns.length}';
  }

  static String _buildStoreContext(List<Transaction> txns) {
    final Map<String, double> byStore = {};
    for (final t in txns) {
      if (t.isExpense && t.storeName.isNotEmpty) {
        byStore[t.storeName] = (byStore[t.storeName] ?? 0) + t.amount;
      }
    }
    if (byStore.isEmpty) return 'No store data available.';
    final sorted = byStore.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(15).map((e) => '  ${e.key}: RM${e.value.toStringAsFixed(2)}').join('\n');
  }

  static String _guessCategory(String title, String store) {
    final text = '${title.toLowerCase()} ${store.toLowerCase()}';
    if (text.contains('grab') || text.contains('myrapid') || text.contains('petrol') || text.contains('parking')) return 'Transport';
    if (text.contains('mcd') || text.contains('mcdonald') || text.contains('kfc') || text.contains('pizza') || text.contains('restaurant')) return 'Food & Dining';
    if (text.contains('tesco') || text.contains('lotus') || text.contains('mydin') || text.contains('aeon') || text.contains('jaya grocer')) return 'Groceries';
    if (text.contains('netflix') || text.contains('spotify') || text.contains('youtube')) return 'Subscriptions';
    if (text.contains('cinema') || text.contains('gsc') || text.contains('tgv')) return 'Entertainment';
    if (text.contains('clinic') || text.contains('hospital') || text.contains('pharmacy')) return 'Health';
    if (text.contains('shopee') || text.contains('lazada') || text.contains('zalora')) return 'Shopping';
    if (text.contains('unifi') || text.contains('tnb') || text.contains('water') || text.contains('electric')) return 'Utilities';
    return 'Other';
  }

  static Map<String, dynamic> _mockReceiptData() => {
    'store_name': 'Jaya Grocer',
    'date': DateTime.now().toIso8601String().substring(0, 10),
    'total_amount': 67.80,
    'currency': 'RM',
    'category': 'Groceries',
    'items': ['Organic Milk 1L - RM 7.90', 'Bread Loaf - RM 4.50', 'Eggs 10pcs - RM 8.90', 'Chicken Breast 500g - RM 14.50', 'Mixed Vegetables - RM 6.00'],
    'confidence': 0.85,
  };

  static String _mockChatResponse(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('save') || lower.contains('saving')) {
      return '💡 **Here are 3 quick wins to save more:**\n\n• **Cut food delivery** — cooking twice a week saves ~RM150/month\n• **Review subscriptions** — cancel unused streaming services\n• **Set a weekly cash limit** — RM50/week for dining out keeps you on track\n\nWant me to create a savings goal?';
    }
    if (lower.contains('budget')) {
      return '📊 **Budget Recommendation:**\n\nBased on your spending, I suggest:\n• **Food & Dining:** RM 600/month\n• **Transport:** RM 300/month\n• **Entertainment:** RM 150/month\n\nThis follows the **50/30/20 rule** — needs/wants/savings. Shall I set these budgets?';
    }
    if (lower.contains('spend') || lower.contains('analys')) {
      return '📈 **Spending Analysis:**\n\nYour biggest categories this month are **Food & Dining** and **Shopping**. You\'re on track with Transport. \n\n⚠️ Food spending is 23% above your monthly average — consider meal prepping!';
    }
    return '🤖 I\'m AiLedge, your financial advisor! I can help you:\n• **Analyze** your spending patterns\n• **Set budgets** for each category\n• **Suggest** ways to save money\n• **Review** your financial goals\n\nWhat would you like to explore?';
  }

  static List<String> _mockInsights() => [
    '🍔 Food & Dining is 42% of total spending',
    '🏪 Jaya Grocer is cheapest for groceries in history',
    '💡 Switch 2 meals/week to cooking — saves ~RM 120/mo',
    '📱 Subscriptions detected — review if all are used',
    '🛒 GrabFood orders cost 35% more than dine-in',
  ];

  static List<Map<String, dynamic>> _mockGrocerySuggestions(List<String> items) {
    return items.map((item) => {
      'item': item,
      'suggestions': [
        {'store': "Lotus's", 'est_price': 'RM 5–8', 'rating': 'Budget', 'note': 'Best everyday value'},
        {'store': 'Jaya Grocer', 'est_price': 'RM 7–12', 'rating': 'Mid', 'note': 'Good quality'},
        {'store': 'AEON', 'est_price': 'RM 6–10', 'rating': 'Mid', 'note': 'Wide selection'},
      ],
    }).toList();
  }
}
