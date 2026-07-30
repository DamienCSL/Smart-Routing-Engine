import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/network/supabase_client.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/utils/logger.dart';
import 'app.dart';

/// Bootstraps environment, optional Supabase / Firebase, and runs the app.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.load();
  await FirebaseBootstrap.initIfEnabled();

  if (Env.isSupabaseConfigured) {
    try {
      await initializeSupabase();
      AppLogger.info('Supabase initialized');
    } catch (e, st) {
      AppLogger.error('Supabase init failed', e, st);
    }
  } else if (Env.useDriverApi) {
    AppLogger.info(
      'Driver API mode — MySQL master via ${Env.driverApiUrl} (no Supabase)',
    );
  } else {
    AppLogger.info('No backend configured — splash / offline demo');
  }

  runApp(
    const ProviderScope(
      child: IposbApp(),
    ),
  );
}
