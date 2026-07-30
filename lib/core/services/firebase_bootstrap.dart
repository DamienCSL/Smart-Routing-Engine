import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../utils/logger.dart';

/// Initializes Firebase when USE_FIREBASE=true.
/// Add platform options (`google-services.json` / `GoogleService-Info.plist`)
/// before enabling in production. Demo mode keeps USE_FIREBASE=false.
abstract final class FirebaseBootstrap {
  static Future<void> initIfEnabled() async {
    if (!Env.useFirebase) {
      AppLogger.info('Firebase disabled (USE_FIREBASE=false)');
      return;
    }
    try {
      // Production: await Firebase.initializeApp(); then request FCM permission
      // and call DriverPushService.registerToken with Messaging.instance.getToken().
      AppLogger.info(
        'USE_FIREBASE=true — complete Firebase.initializeApp() for '
        '${kIsWeb ? 'web' : 'mobile'} before shipping FCM.',
      );
    } catch (e, st) {
      AppLogger.error('Firebase bootstrap skipped', e, st);
    }
  }
}
