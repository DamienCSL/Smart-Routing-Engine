import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps driving directions to a stop (external app / browser).
abstract final class GoogleMapsLauncher {
  /// Prefer lat/lng when available; otherwise fall back to a text address.
  static Future<bool> openDirections({
    double? lat,
    double? lng,
    String? address,
  }) async {
    final hasCoords = lat != null && lng != null;
    final trimmed = address?.trim();
    final hasAddress = trimmed != null && trimmed.isNotEmpty;

    if (!hasCoords && !hasAddress) return false;

    final destination = hasCoords
        ? '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}'
        : Uri.encodeComponent(trimmed!);

    final web = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$destination'
      '&travelmode=driving',
    );

    if (await canLaunchUrl(web)) {
      return launchUrl(web, mode: LaunchMode.externalApplication);
    }

    // Fallback: same URL in the current browser tab (Flutter web).
    return launchUrl(web, mode: LaunchMode.platformDefault);
  }
}
