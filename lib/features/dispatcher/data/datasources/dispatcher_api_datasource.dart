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

    final id = session.dispatcherId?.toString() ??
        match?['id']?.toString() ??
        session.userId.toString();
    return DispatcherProfile(
      id: id,
      zone: (match?['zoneCode'] ?? 'KK-METRO').toString(),
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

  Future<List<ZoneDriverSummary>> getDrivers() async {
    final profile = await getCurrentProfile();
    final json = await _api.getJson('/dispatch/drivers', query: {
      'available': '0',
    });
    final drivers = json['drivers'] as List<dynamic>? ?? const [];
    return drivers.map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final name = (row['fullName'] ?? 'Driver').toString();
      final route = (row['routeCd'] ?? row['locId'] ?? '').toString();
      return ZoneDriverSummary(
        id: '${row['driverId'] ?? ''}',
        zone: profile.zone,
        vehicleType: route.isNotEmpty ? route : 'driver',
        vehiclePlate: name,
        isAvailable: row['isAvailable'] == true,
        driverName: name,
      );
    }).toList();
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

  Shipment _shipmentFromJob(Map<String, dynamic> job) {
    final cnNo = job['cnNo']?.toString() ?? '';
    final jobType = job['jobType']?.toString() ?? 'delivery';
    final origin = job['originLoc']?.toString() ?? '';
    final dest = job['destLoc']?.toString() ?? '';
    final address = job['address']?.toString() ?? '';
    return Shipment(
      id: cnNo,
      trackingNumber: cnNo,
      customerId: 'fms',
      originAddress: jobType == 'pickup' ? address : origin,
      originCity: origin,
      originProvince: 'Sabah',
      originZone: origin,
      destinationAddress: jobType == 'delivery' ? address : dest,
      destinationCity: dest,
      destinationProvince: 'Sabah',
      destinationZone: dest,
      weightKg: (job['weight'] as num?)?.toDouble() ?? 0,
      packageCount: (job['pieces'] as num?)?.toInt() ?? 1,
      status: ShipmentStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      packageDescription: job['recipientName']?.toString(),
    );
  }
}
