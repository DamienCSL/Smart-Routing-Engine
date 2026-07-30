import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../utils/logger.dart';

/// Runtime environment — supports legacy Supabase demo OR Driver API + Firebase.
abstract final class Env {
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
    AppLogger.info(
      'Env loaded — driverApi=$useDriverApi url=$driverApiUrl '
      'supabaseConfigured=$isSupabaseConfigured',
    );
  }

  static String get supabaseUrl =>
      (dotenv.env['SUPABASE_URL'] ?? '').trim();

  static String get supabaseAnonKey =>
      (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('your-project') &&
      supabaseUrl.startsWith('https://');

  /// When true, hub-worker / driver flows use IPOSB Driver API (MySQL master).
  static bool get useDriverApi {
    final flag = (dotenv.env['USE_DRIVER_API'] ?? '').trim().toLowerCase();
    if (flag == 'true' || flag == '1') return true;
    if (flag == 'false' || flag == '0') return false;
    return driverApiUrl.isNotEmpty;
  }

  static String get driverApiUrl =>
      (dotenv.env['DRIVER_API_URL'] ?? 'http://127.0.0.1:3080').trim();

  /// Demo Firebase uid for local API (`Authorization: Bearer demo:<uid>`).
  static String get demoDriverUid =>
      (dotenv.env['DEMO_DRIVER_UID'] ?? 'demo-driver-kk').trim();

  /// Same key as driver-api DISPATCH_API_KEY (demo create order / ops scan).
  static String get dispatchApiKey =>
      (dotenv.env['DISPATCH_API_KEY'] ?? 'iposb-dispatch-dev-key').trim();

  static bool get useFirebase {
    final flag = (dotenv.env['USE_FIREBASE'] ?? '').trim().toLowerCase();
    return flag == 'true' || flag == '1';
  }

  /// App is usable if either backend is configured.
  static bool get isConfigured => useDriverApi || isSupabaseConfigured;
}
