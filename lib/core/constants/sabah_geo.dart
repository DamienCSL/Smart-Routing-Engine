import 'package:latlong2/latlong.dart';

import 'demo_zones.dart';

/// Sabah map defaults + zone inference for ops (driver / dispatcher) maps.
abstract final class SabahGeo {
  /// Approximate state bounding box (south, west, north, east).
  static const double south = 4.05;
  static const double west = 115.15;
  static const double north = 7.45;
  static const double east = 119.55;

  static final LatLng center = LatLng(5.65, 117.05);

  static const double defaultZoom = 8.2;

  /// Zone centroids used for nearest-zone detection from a pin.
  static final Map<String, LatLng> zoneCentroids = {
    DemoZones.kkMetro: LatLng(5.9804, 116.0735),
    DemoZones.westCoast: LatLng(6.2800, 116.4300),
    DemoZones.interior: LatLng(5.3400, 116.1600),
    DemoZones.sandakan: LatLng(5.8400, 118.1170),
    DemoZones.tawau: LatLng(4.2500, 117.8900),
  };

  /// Seeded network nodes shown as reference markers on the ops map.
  static final List<SabahNetworkPoint> networkPoints = [
    SabahNetworkPoint(
      code: 'HUB-ON-01',
      name: 'KK Origin Hub',
      zone: DemoZones.kkMetro,
      point: LatLng(5.9950, 116.1180),
      kind: SabahNetworkKind.hub,
    ),
    SabahNetworkPoint(
      code: 'DP-ON-01',
      name: 'KK Likas Drop Point',
      zone: DemoZones.kkMetro,
      point: LatLng(5.9965, 116.1010),
      kind: SabahNetworkKind.dropPoint,
    ),
    SabahNetworkPoint(
      code: 'HUB-SH-01',
      name: 'Ranau Sorting Hub',
      zone: DemoZones.interior,
      point: LatLng(5.9530, 116.6640),
      kind: SabahNetworkKind.hub,
    ),
    SabahNetworkPoint(
      code: 'HUB-DH-01',
      name: 'Sandakan Destination Hub',
      zone: DemoZones.sandakan,
      point: LatLng(5.8750, 118.0750),
      kind: SabahNetworkKind.hub,
    ),
    SabahNetworkPoint(
      code: 'DP-DH-01',
      name: 'Sandakan Town Drop Point',
      zone: DemoZones.sandakan,
      point: LatLng(5.8400, 118.1170),
      kind: SabahNetworkKind.dropPoint,
    ),
  ];

  static bool contains(LatLng point) {
    return point.latitude >= south &&
        point.latitude <= north &&
        point.longitude >= west &&
        point.longitude <= east;
  }

  static LatLng centerForZone(String? zoneCode) {
    return zoneCentroids[zoneCode] ?? center;
  }

  /// Nearest Sabah logistics zone to [point] (centroid distance).
  static String zoneCodeFor(LatLng point) {
    const distance = Distance();
    var bestCode = DemoZones.kkMetro;
    var bestMeters = double.infinity;

    for (final entry in zoneCentroids.entries) {
      final meters = distance(point, entry.value);
      if (meters < bestMeters) {
        bestMeters = meters;
        bestCode = entry.key;
      }
    }
    return bestCode;
  }

  /// Nearest seeded hub/drop-point to [point] (driver/dispatcher route start).
  static SabahNetworkPoint nearestNetworkPoint(LatLng point) {
    const distance = Distance();
    var best = networkPoints.first;
    var bestMeters = distance(point, best.point);

    for (final node in networkPoints.skip(1)) {
      final meters = distance(point, node.point);
      if (meters < bestMeters) {
        bestMeters = meters;
        best = node;
      }
    }
    return best;
  }

  /// Depot used when driving out for pickups in a zone.
  static LatLng pickupDepotForZone(String? zoneCode) {
    final zone = zoneCode ?? DemoZones.kkMetro;
    for (final node in networkPoints) {
      if (node.zone == zone && node.kind == SabahNetworkKind.dropPoint) {
        return node.point;
      }
    }
    for (final node in networkPoints) {
      if (node.zone == zone) return node.point;
    }
    return centerForZone(zone);
  }

  /// Depot used when heading toward delivery destinations in a zone.
  static LatLng deliveryDepotForZone(String? zoneCode) {
    final zone = zoneCode ?? DemoZones.sandakan;
    for (final node in networkPoints) {
      if (node.zone == zone && node.kind == SabahNetworkKind.hub) {
        return node.point;
      }
    }
    return centerForZone(zone);
  }
}

enum SabahNetworkKind { hub, dropPoint }

class SabahNetworkPoint {
  const SabahNetworkPoint({
    required this.code,
    required this.name,
    required this.zone,
    required this.point,
    required this.kind,
  });

  final String code;
  final String name;
  final String zone;
  final LatLng point;
  final SabahNetworkKind kind;
}
