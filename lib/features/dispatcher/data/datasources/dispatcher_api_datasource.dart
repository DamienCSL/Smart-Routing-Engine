import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/driver_api_client.dart';
import '../../../../core/network/driver_api_session.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../shipment/domain/entities/shipment.dart';
import '../../domain/entities/dispatcher_profile.dart';
import '../../domain/entities/zone_driver_summary.dart';

/// Dispatcher desk backed by IPOSB `/dispatch/*` + `/dispatchers` (MySQL).
class DispatcherApiDataSource {
  DispatcherApiDataSource(this._api, this._session);

  final DriverApiClient _api;
  final DriverApiSession? _session;

  Future<DispatcherProfile> getCurrentProfile() async {
    final session = _session;
    if (session == null || session.role != UserRole.dispatcher) {
      throw const AuthException('Not signed in as a dispatcher');
    }

    try {
      final me = await _api.getJson('/dispatcher/me');
      final prefs = _parseZones(me['preferredZones']);
      return DispatcherProfile(
        id: '${me['id'] ?? session.dispatcherId ?? session.userId}',
        zone: (me['zoneCode'] ??
                (prefs.isNotEmpty ? prefs.first : 'KK-METRO'))
            .toString(),
        hubId: me['branchCode']?.toString(),
      );
    } catch (_) {
      // Fall through to catalog lookup.
    }

    Map<String, dynamic>? match;
    try {
      final json = await _api.getJson('/dispatchers');
      final list = json['dispatchers'] as List<dynamic>? ?? const [];
      for (final raw in list) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = int.tryParse('${row['id'] ?? ''}');
        if (session.dispatcherId != null && id == session.dispatcherId) {
          match = row;
          break;
        }
        if (session.email.isNotEmpty &&
            (row['mobileEmail']?.toString() ?? row['email']?.toString()) ==
                session.email) {
          match = row;
          break;
        }
      }
    } catch (_) {
      // Fall through to session-only profile.
    }

    final prefs = _parseZones(match?['preferredZones']);
    final id = session.dispatcherId?.toString() ??
        match?['id']?.toString() ??
        session.userId.toString();
    return DispatcherProfile(
      id: id,
      zone: (match?['zoneCode'] ??
              (prefs.isNotEmpty ? prefs.first : null) ??
              (session.preferredZones.isNotEmpty
                  ? session.preferredZones.first
                  : 'KK-METRO'))
          .toString(),
      hubId: match?['branchCode']?.toString(),
    );
  }

  Future<List<Shipment>> getUnassignedJobs() async {
    final json = await _api.getJson('/dispatch/jobs', query: {'limit': '50'});
    final jobs = json['jobs'] as List<dynamic>? ?? const [];
    return jobs
        .map((raw) => _shipmentFromJob(Map<String, dynamic>.from(raw as Map)))
        .toList();
  }

  Stream<List<Shipment>> watchUnassignedJobs() async* {
    yield await getUnassignedJobs();
    yield* Stream.periodic(const Duration(seconds: 12))
        .asyncMap((_) => getUnassignedJobs());
  }

  Future<List<ZoneDriverSummary>> getDrivers({
    String? zone,
    String jobType = 'delivery',
  }) async {
    final profile = await getCurrentProfile();
    final query = <String, String>{
      'available': '0',
      if (zone != null && zone.isNotEmpty) 'zone': zone,
      'jobType': jobType,
    };
    final json = await _api.getJson('/dispatch/drivers', query: query);
    final drivers = json['drivers'] as List<dynamic>? ?? const [];
    return drivers.map((raw) => _driverFromRow(
          Map<String, dynamic>.from(raw as Map),
          fallbackZone: profile.zone,
        )).toList();
  }

  Future<DispatchSuggestResult> suggestForJob({
    required String cnNo,
    String jobType = 'delivery',
  }) async {
    final json = await _api.getJson('/dispatch/suggest', query: {
      'cnNo': cnNo,
      'jobType': jobType,
    });
    final drivers = json['drivers'] as List<dynamic>? ?? const [];
    final target = (json['targetZone'] ?? '').toString();
    final routeRaw = json['route'];
    DispatchRouteHint? route;
    if (routeRaw is Map) {
      final r = Map<String, dynamic>.from(routeRaw);
      final rule = r['rule'];
      final ruleMap = rule is Map ? Map<String, dynamic>.from(rule) : null;
      route = DispatchRouteHint(
        matched: r['matched'] == true,
        ruleCode: (ruleMap?['ruleCode'] ?? r['ruleCode'])?.toString(),
        viaHubCode: r['viaHubCode']?.toString(),
        destHubCode: r['destHubCode']?.toString(),
        preferredRouteCd: r['preferredRouteCd']?.toString(),
        originDropCode: r['originDropCode']?.toString(),
        destDropCode: r['destDropCode']?.toString(),
      );
    }
    return DispatchSuggestResult(
      cnNo: (json['cnNo'] ?? cnNo).toString(),
      jobType: (json['jobType'] ?? jobType).toString(),
      targetZone: target,
      originZone: (json['originZone'] ?? '').toString(),
      destinationZone: (json['destinationZone'] ?? '').toString(),
      route: route,
      drivers: drivers
          .map((raw) => _driverFromRow(
                Map<String, dynamic>.from(raw as Map),
                fallbackZone: target,
              ))
          .toList(),
    );
  }

  /// Kept for older call sites.
  Future<List<ZoneDriverSummary>> suggestDrivers({
    required String cnNo,
    String jobType = 'delivery',
  }) async {
    final result = await suggestForJob(cnNo: cnNo, jobType: jobType);
    return result.drivers;
  }

  Future<void> assignJob({
    required String cnNo,
    required String firebaseUid,
    String jobType = 'delivery',
  }) async {
    await _api.postJson('/dispatch/assign', body: {
      'cnNo': cnNo,
      'firebaseUid': firebaseUid,
      'jobType': jobType,
    });
  }

  Future<void> unassignJob({required String cnNo}) async {
    await _api.postJson('/dispatch/unassign', body: {'cnNo': cnNo});
  }

  ZoneDriverSummary _driverFromRow(
    Map<String, dynamic> row, {
    required String fallbackZone,
  }) {
    final name = (row['fullName'] ?? 'Driver').toString();
    final route = (row['routeCd'] ?? row['locId'] ?? '').toString();
    final prefs = _parseZones(row['preferredZones']);
    return ZoneDriverSummary(
      id: '${row['driverId'] ?? ''}',
      zone: prefs.isNotEmpty ? prefs.first : fallbackZone,
      vehicleType: route.isNotEmpty ? route : 'driver',
      vehiclePlate: name,
      isAvailable: row['isAvailable'] == true,
      driverName: name,
      preferredZones: prefs,
      zoneMatch: row['zoneMatch'] == true,
      routeMatch: row['routeMatch'] == true,
      matchScore: (row['matchScore'] as num?)?.toInt() ?? 0,
      firebaseUid: row['firebaseUid']?.toString(),
    );
  }

  List<String> _parseZones(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Shipment _shipmentFromJob(Map<String, dynamic> job) {
    final cnNo = job['cnNo']?.toString() ?? '';
    final jobType = job['jobType']?.toString() ?? 'delivery';
    final origin = job['originLoc']?.toString() ?? '';
    final dest = job['destLoc']?.toString() ?? '';
    final address = job['address']?.toString() ?? '';
    final originZone =
        (job['originZone'] ?? origin).toString();
    final destZone =
        (job['destinationZone'] ?? dest).toString();
    return Shipment(
      id: cnNo,
      trackingNumber: cnNo,
      customerId: 'fms',
      originAddress: jobType == 'pickup' ? address : origin,
      originCity: origin,
      originProvince: 'Sabah',
      originZone: originZone,
      destinationAddress: jobType == 'delivery' ? address : dest,
      destinationCity: dest,
      destinationProvince: 'Sabah',
      destinationZone: destZone,
      weightKg: (job['weight'] as num?)?.toDouble() ?? 0,
      packageCount: (job['pieces'] as num?)?.toInt() ?? 1,
      status: ShipmentStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      packageDescription: job['recipientName']?.toString(),
    );
  }
}
