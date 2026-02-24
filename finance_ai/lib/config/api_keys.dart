import 'package:flutter_dotenv/flutter_dotenv.dart';

// 🔐 API Keys Configuration
// Replace with your actual Gemini API key from https://aistudio.google.com/
class ApiKeys {
  static String get gemini => dotenv.env['GEMINI_API_KEY'] ?? '';
}
