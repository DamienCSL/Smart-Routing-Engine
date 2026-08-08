import 'dart:convert';

/// Shared QR payload contract for shipment labels and scanners.
abstract final class ShipmentQrPayload {
  /// Keep labels compatible with existing IPOSB scanners by encoding the CN.
  static String encode(String cnNo) => cnNo.trim();

  /// Accept current plain-CN labels plus common URL/JSON label formats.
  static String decode(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        final cn =
            decoded['cnNo'] ?? decoded['trackingNumber'] ?? decoded['cn'];
        if (cn != null && cn.toString().trim().isNotEmpty) {
          return cn.toString().trim();
        }
      }
    } catch (_) {
      // Plain CN and URL payloads are handled below.
    }

    const prefix = 'IPOSB:CN:';
    if (value.toUpperCase().startsWith(prefix)) {
      return value.substring(prefix.length).trim();
    }

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      final fromQuery =
          uri.queryParameters['cn'] ?? uri.queryParameters['cnNo'];
      if (fromQuery != null && fromQuery.trim().isNotEmpty) {
        return fromQuery.trim();
      }
      if (uri.pathSegments.isNotEmpty) {
        final fromPath = uri.pathSegments.last.trim();
        if (fromPath.isNotEmpty) return fromPath;
      }
    }
    return value;
  }
}
