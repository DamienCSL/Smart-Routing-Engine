import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Global Supabase client accessor (only when Supabase is configured).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  if (!Env.isSupabaseConfigured) {
    throw StateError(
      'Supabase is not configured. Enable USE_DRIVER_API or set SUPABASE_URL.',
    );
  }
  return Supabase.instance.client;
});

/// Initializes Supabase with environment credentials.
Future<void> initializeSupabase() async {
  if (!Env.isSupabaseConfigured) return;

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );
}
