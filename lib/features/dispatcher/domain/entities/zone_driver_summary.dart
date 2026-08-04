/// Result of GET /dispatch/suggest (drivers + route hint).
class DispatchSuggestResult {
  const DispatchSuggestResult({
    required this.cnNo,
    required this.jobType,
    required this.targetZone,
    required this.originZone,
    required this.destinationZone,
    required this.drivers,
    this.route,
  });

  final String cnNo;
  final String jobType;
  final String targetZone;
  final String originZone;
  final String destinationZone;
  final List<ZoneDriverSummary> drivers;
  final DispatchRouteHint? route;
}

class DispatchRouteHint {
  const DispatchRouteHint({
    required this.matched,
    this.ruleCode,
    this.viaHubCode,
    this.destHubCode,
    this.preferredRouteCd,
    this.originDropCode,
    this.destDropCode,
  });

  final bool matched;
  final String? ruleCode;
  final String? viaHubCode;
  final String? destHubCode;
  final String? preferredRouteCd;
  final String? originDropCode;
  final String? destDropCode;

  String get summary {
    if (!matched) return 'No route rule matched — ranking by zone only';
    final parts = <String>[];
    if (ruleCode != null && ruleCode!.isNotEmpty) parts.add(ruleCode!);
    if (viaHubCode != null && viaHubCode!.isNotEmpty) {
      parts.add('via $viaHubCode');
    }
    if (destHubCode != null && destHubCode!.isNotEmpty) {
      parts.add('→ $destHubCode');
    }
    if (preferredRouteCd != null && preferredRouteCd!.isNotEmpty) {
      parts.add('pool $preferredRouteCd');
    }
    return parts.isEmpty ? 'Route matched' : parts.join(' · ');
  }
}

/// Driver availability in a logistics zone (demo dashboard).
class ZoneDriverSummary {
  const ZoneDriverSummary({
    required this.id,
    required this.zone,
    required this.vehicleType,
    required this.vehiclePlate,
    required this.isAvailable,
    this.driverName,
    this.preferredZones = const [],
    this.zoneMatch = false,
    this.routeMatch = false,
    this.matchScore = 0,
    this.firebaseUid,
  });

  final String id;
  final String zone;
  final String vehicleType;
  final String vehiclePlate;
  final bool isAvailable;
  final String? driverName;
  final List<String> preferredZones;
  final bool zoneMatch;
  final bool routeMatch;
  final int matchScore;
  final String? firebaseUid;
}
