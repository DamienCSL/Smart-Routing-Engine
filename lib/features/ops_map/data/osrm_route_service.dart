import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A driving path between two points (road geometry when available).
class DrivingRoute {
  const DrivingRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.label,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final String? label;

  String get distanceLabel {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  String get durationLabel {
    final minutes = (durationSeconds / 60).round().clamp(1, 9999);
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return '${h}h ${m}m';
    }
    return '$minutes min';
  }
}

/// Road directions via the public OSRM demo server (no API key; fine for demos).
class OsrmRouteService {
  OsrmRouteService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<DrivingRoute> route({
    required LatLng from,
    required LatLng to,
    String? label,
  }) async {
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/'
          '${from.longitude},${from.latitude};'
          '${to.longitude},${to.latitude}',
      {
        'overview': 'full',
        'geometries': 'geojson',
      },
    );

    try {
      final response = await _client.get(uri, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['code'] == 'Ok') {
          final routes = body['routes'] as List<dynamic>?;
          if (routes != null && routes.isNotEmpty) {
            final route = routes.first as Map<String, dynamic>;
            final geometry = route['geometry'] as Map<String, dynamic>;
            final coords = geometry['coordinates'] as List<dynamic>;
            final points = coords.map((c) {
              final pair = c as List<dynamic>;
              return LatLng(
                (pair[1] as num).toDouble(),
                (pair[0] as num).toDouble(),
              );
            }).toList();

            if (points.length >= 2) {
              return DrivingRoute(
                points: points,
                distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
                durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
                label: label,
              );
            }
          }
        }
      }
    } catch (_) {
      // Fall through to straight-line fallback.
    }

    const distance = Distance();
    final meters = distance(from, to);
    return DrivingRoute(
      points: [from, to],
      distanceMeters: meters,
      durationSeconds: meters / 8.3, // ~30 km/h rough ETA
      label: label,
    );
  }

  Future<List<DrivingRoute>> routesForTargets({
    required LatLng from,
    required List<({LatLng to, String? label})> targets,
  }) async {
    if (targets.isEmpty) return const [];
    return Future.wait(
      targets.map(
        (t) => route(from: from, to: t.to, label: t.label),
      ),
    );
  }
}
