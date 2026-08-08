import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/sabah_geo.dart';
import '../domain/entities/picked_location.dart';

/// OpenStreetMap Nominatim geocoding for the Leaflet-style Sabah map.
class SabahGeocoder {
  SabahGeocoder({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _userAgent = 'IPOSB-SmartRouting/1.0';

  /// Place search biased toward Sabah / Malaysia.
  Future<List<GeocodeSuggestion>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': '$q, Sabah, Malaysia',
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '8',
      'countrycodes': 'my',
      'accept-language': 'en',
      // left, top, right, bottom — keeps results around Sabah.
      'viewbox': '115.0,7.5,119.6,4.0',
      'bounded': '1',
    });

    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json', 'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) {
      throw Exception('Location search failed (${response.statusCode})');
    }

    final results = jsonDecode(response.body) as List<dynamic>? ?? const [];

    final suggestions = <GeocodeSuggestion>[];
    for (final raw in results) {
      final map = raw as Map<String, dynamic>;
      final lat = double.tryParse('${map['lat'] ?? ''}');
      final lng = double.tryParse('${map['lon'] ?? ''}');
      if (lat == null || lng == null) continue;

      final point = LatLng(lat, lng);
      if (!SabahGeo.contains(point)) continue;

      final label = (map['display_name'] as String?)?.trim() ?? '';
      if (label.isEmpty) continue;
      final address = map['address'] is Map
          ? Map<String, dynamic>.from(map['address'] as Map)
          : const <String, dynamic>{};
      final city = _firstNonEmpty([
        address['city'],
        address['town'],
        address['municipality'],
        address['village'],
        address['county'],
      ]);
      final state = _firstNonEmpty([address['state']]) ?? 'Sabah';

      suggestions.add(
        GeocodeSuggestion(point: point, label: label, city: city, state: state),
      );
    }

    return suggestions;
  }

  /// Reverse geocode a pin for a readable address line.
  Future<PickedLocation> reverse(
    LatLng point, {
    required String zoneCode,
  }) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': point.latitude.toString(),
      'lon': point.longitude.toString(),
      'format': 'jsonv2',
      'addressdetails': '1',
      'zoom': '18',
      'accept-language': 'en',
    });

    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json', 'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) {
      throw Exception('Address lookup failed (${response.statusCode})');
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final label = (map['display_name'] as String?)?.trim() ?? '';
    if (label.isEmpty) throw Exception('No address found for this location');
    final address = map['address'] is Map
        ? Map<String, dynamic>.from(map['address'] as Map)
        : const <String, dynamic>{};
    final city = _firstNonEmpty([
      address['city'],
      address['town'],
      address['municipality'],
      address['village'],
      address['county'],
    ]);
    final state = _firstNonEmpty([address['state']]) ?? 'Sabah';

    return PickedLocation(
      point: point,
      label: label,
      zoneCode: zoneCode,
      city: city,
      state: state,
    );
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
