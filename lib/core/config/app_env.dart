import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized environment configuration loaded from `.env` at startup.
class AppEnv {
  AppEnv._();

  static bool _loaded = false;
  static bool firebaseInitialized = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      await dotenv.load(fileName: '.env');
      _loaded = true;
    } catch (_) {
      // Fallback gracefully in unit/widget tests where .env asset isn't loaded
      _loaded = false;
    }
  }

  static String _get(String key, String fallback) {
    if (!_loaded) return fallback;
    return dotenv.env[key]?.trim().isNotEmpty == true
        ? dotenv.env[key]!.trim()
        : fallback;
  }

  static String get firebaseProjectId =>
      _get('FIREBASE_PROJECT_ID', 'traveltourism-32d7d');

  static String get mongoDbUri =>
      _get('MONGODB_URI', 'mongodb://localhost:27018/service_epic');

  static String get backendApiUrl =>
      _get('BACKEND_API_URL', 'http://10.0.2.2:5000/api/v1');

  static String get razorpayKeyId =>
      _get('RAZORPAY_KEY_ID', 'rzp_test_TIAeiYL9M3K4lC');
}
