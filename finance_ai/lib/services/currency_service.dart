import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyService {
  static const String _baseUrl = 'https://open.er-api.com/v6/latest';

  /// Fetches exchange rates relative to a base currency (default MYR)
  static Future<Map<String, double>> fetchRates([String baseCurrency = 'MYR']) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$baseCurrency'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] == 'success') {
          final rates = data['rates'] as Map<String, dynamic>;
          return rates.map((key, value) => MapEntry(key, (value as num).toDouble()));
        }
      }
    } catch (e) {
      // Fallback if API fails
      print('CurrencyService error: $e');
    }
    // Return empty map on failure to maintain existing rates
    return {};
  }
}
