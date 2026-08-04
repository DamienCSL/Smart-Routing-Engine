/// Facility tree: Hub → Minihub/Station → Drop Point.
///
/// Receive rules:
/// - Station/minihub receives only from its parent hub.
/// - Drop point receives only from its parent station/minihub.
library;

enum LocationLevel {
  hub,
  minihub,
  station;

  static LocationLevel fromApi(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'minihub':
        return LocationLevel.minihub;
      case 'station':
        return LocationLevel.station;
      default:
        return LocationLevel.hub;
    }
  }

  String get apiValue => name;

  String get label => switch (this) {
        LocationLevel.hub => 'Hub',
        LocationLevel.minihub => 'Minihub',
        LocationLevel.station => 'Station',
      };

  bool get isStationTier =>
      this == LocationLevel.minihub || this == LocationLevel.station;
}

class FacilityNode {
  const FacilityNode({
    required this.code,
    required this.name,
    required this.level,
    this.parentHubCode,
    this.hubType,
    this.branchCode,
    this.stations = const [],
    this.dropPoints = const [],
  });

  final String code;
  final String name;
  final LocationLevel level;
  final String? parentHubCode;
  final String? hubType;
  final String? branchCode;
  final List<FacilityNode> stations;
  final List<DropPointNode> dropPoints;

  bool get isRootHub => level == LocationLevel.hub;
  bool get isStationTier => level.isStationTier;

  factory FacilityNode.fromJson(Map<String, dynamic> json) {
    final stationsRaw = (json['stations'] as List<dynamic>?) ?? const [];
    final dropsRaw = (json['dropPoints'] as List<dynamic>?) ?? const [];
    return FacilityNode(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      level: LocationLevel.fromApi(json['locationLevel']?.toString()),
      parentHubCode: json['parentHubCode']?.toString(),
      hubType: json['hubType']?.toString(),
      branchCode: json['branchCode']?.toString(),
      stations: stationsRaw
          .whereType<Map>()
          .map((e) => FacilityNode.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      dropPoints: dropsRaw
          .whereType<Map>()
          .map((e) => DropPointNode.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class DropPointNode {
  const DropPointNode({
    required this.id,
    required this.code,
    required this.name,
    this.stationCode,
    this.dropType,
  });

  final int id;
  final String code;
  final String name;
  final String? stationCode;
  final String? dropType;

  factory DropPointNode.fromJson(Map<String, dynamic> json) {
    return DropPointNode(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      stationCode:
          (json['stationCode'] ?? json['hubCode'])?.toString(),
      dropType: json['dropType']?.toString(),
    );
  }
}

/// Helpers for cascading Hub → Station → Drop Point pickers.
abstract final class LocationTreeRules {
  /// Drop points may only hang under a station/minihub.
  static bool canAttachDropTo(FacilityNode node) => node.isStationTier;

  /// Stations receive from their parent hub only.
  static bool stationBelongsToHub(FacilityNode station, String hubCode) =>
      station.isStationTier &&
      (station.parentHubCode ?? '').toUpperCase() == hubCode.toUpperCase();

  /// Drop points receive from their parent station only.
  static bool dropBelongsToStation(DropPointNode drop, String stationCode) =>
      (drop.stationCode ?? '').toUpperCase() == stationCode.toUpperCase();

  static List<FacilityNode> stationsUnder(
    List<FacilityNode> tree,
    String hubCode,
  ) {
    for (final hub in tree) {
      if (hub.code.toUpperCase() == hubCode.toUpperCase()) {
        return hub.stations;
      }
    }
    return const [];
  }

  static List<DropPointNode> dropsUnderStation(
    List<FacilityNode> tree,
    String stationCode,
  ) {
    for (final hub in tree) {
      for (final st in hub.stations) {
        if (st.code.toUpperCase() == stationCode.toUpperCase()) {
          return st.dropPoints;
        }
      }
    }
    return const [];
  }
}
