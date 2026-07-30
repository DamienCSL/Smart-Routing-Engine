import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/sabah_geo.dart';
import '../domain/entities/picked_location.dart';

/// Geocoding for Sabah ops maps (CORS-friendly APIs for Flutter web).
class SabahGeocoder {
  SabahGeocoder({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _userAgent = 'IPOSB-SmartRouting/1.0 (ops-map demo)';

  /// Place search biased toward Sabah / Malaysia.
  Future<List<GeocodeSuggestion>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final uri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {
        'name': q,
        'count': '8',
        'language': 'en',
        'format': 'json',
        'countryCode': 'MY',
      },
    );

    final response = await _client.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': _userAgent,
    });

    if (response.statusCode != 200) {
      throw Exception('Location search failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? const [];

    final suggestions = <GeocodeSuggestion>[];
    for (final raw in results) {
      final map = raw as Map<String, dynamic>;
      final lat = (map['latitude'] as num?)?.toDouble();
      final lng = (map['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final point = LatLng(lat, lng);
      if (!SabahGeo.contains(point)) continue;

      final name = (map['name'] as String?)?.trim() ?? 'Unknown';
      final admin1 = map['admin1'] as String?;
      final admin2 = map['admin2'] as String?;
      final city = admin2 ?? admin1;
      final label = [
        name,
        if (admin2 != null && admin2 != name) admin2,
        if (admin1 != null && admin1 != admin2) admin1,
      ].join(', ');

      suggestions.add(
        GeocodeSuggestion(
          point: point,
          label: label,
          city: city,
          state: 'Sabah',
        ),
      );
    }

    return suggestions;
  }

  /// Reverse geocode a pin for a readable address line.
  Future<PickedLocation> reverse(LatLng point, {required String zoneCode}) async {
    final uri = Uri.https(
      'api.bigdatacloud.net',
      '/data/reverse-geocode-client',
      {
        'latitude': point.latitude.toString(),
        'longitude': point.longitude.toString(),
        'localityLanguage': 'en',
      },
    );

    final response = await _client.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': _userAgent,
    });

    if (response.statusCode != 200) {
      return PickedLocation(
        point: point,
        label:
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
        zoneCode: zoneCode,
      );
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final locality = (map['locality'] as String?)?.trim();
    final city = (map['city'] as String?)?.trim();
    final principal =
        (map['principalSubdivision'] as String?)?.trim() ?? 'Sabah';
    final street = [
      map['localityInfo'] is Map
          ? ((map['localityInfo'] as Map)['informative'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map((e) => e['name'] as String?)
              .whereType<String>()
              .take(2)
              .join(', ')
          : null,
      locality,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();

    final label = street.isNotEmpty
        ? street.join(' · ')
        : [
            if (locality != null && locality.isNotEmpty) locality,
            if (city != null && city.isNotEmpty && city != locality) city,
            principal,
          ].join(', ');

    return PickedLocation(
      point: point,
      label: label.isEmpty
          ? '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}'
          : label,
      zoneCode: zoneCode,
      city: city ?? locality,
      state: principal.contains('Sabah') ? 'Sabah' : principal,
    );
  }
}
