import '../utils/logger.dart';
import '../config/env.dart';
import '../network/driver_api_client.dart';

/// Registers FCM token with Driver API when Firebase Messaging is available.
abstract final class DriverPushService {
  static Future<void> registerToken(
    DriverApiClient api, {
    required String token,
    String platform = 'android',
  }) async {
    if (!Env.useDriverApi) return;
    try {
      await api.postJson(
        '/driver/devices/fcm-token',
        body: {'token': token, 'platform': platform},
      );
      AppLogger.info('FCM token registered with Driver API');
    } catch (e, st) {
      AppLogger.error('FCM register failed', e, st);
    }
  }
}
