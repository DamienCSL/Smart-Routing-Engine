import 'dart:math';

import '../../../../core/constants/app_constants.dart';

/// Generates demo tracking numbers: IPOSB-YYYYMMDD-XXXXXX
abstract final class TrackingNumberService {
  static String generate() {
    final now = DateTime.now().toUtc();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final suffix = _randomSuffix(6);
    return '${AppConstants.trackingPrefix}-$date-$suffix';
  }

  static String _randomSuffix(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
