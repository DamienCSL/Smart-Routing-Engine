import 'dart:async';

import '../../../../core/constants/iposb_status_map.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/driver_api_client.dart';
import '../../../../core/utils/google_maps_launcher.dart';
import '../../../driver/domain/entities/driver_task.dart';
import '../../../shipment/domain/entities/shipment.dart';
import '../../../../shared/enums/shipment_status.dart';

/// Hub-worker tasks backed by IPOSB Driver API (MySQL master).
class HubWorkerApiDataSource {
  HubWorkerApiDataSource(this._api);

  final DriverApiClient _api;

  Future<({String id, String hubId, List<String> preferredZones})>
      getCurrentProfile() async {
    final json = await _api.getJson('/driver/me');
    final zonesRaw = json['preferredZones'];
    final zones = zonesRaw is List
        ? zonesRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final loc = (json['locId'] ?? '').toString();
    return (
      id: json['driverId'].toString(),
      hubId: loc,
      preferredZones: zones.isNotEmpty ? zones : (loc.isNotEmpty ? [loc] : <String>[]),
    );
  }

  Future<List<DriverTask>> getTasks({required DriverTaskType type}) async {
    final json = await _api.getJson(
      '/driver/jobs',
      query: {'type': type.value},
    );
    final jobs = json['jobs'] as List<dynamic>? ?? const [];
    return jobs
        .map((raw) => _taskFromJob(raw as Map<String, dynamic>, type))
        .toList();
  }

  Stream<List<DriverTask>> watchTasks({required DriverTaskType type}) async* {
    yield await getTasks(type: type);
    yield* Stream.periodic(const Duration(seconds: 12))
        .asyncMap((_) => getTasks(type: type));
  }

  Future<DriverTask?> getTaskByShipmentId(String cnNo) async {
    try {
      final json = await _api.getJson('/driver/jobs/$cnNo');
      final job = json['job'] as Map<String, dynamic>?;
      if (job == null) return null;
      final type = job['jobType'] == 'pickup'
          ? DriverTaskType.pickup
          : DriverTaskType.delivery;
      return _taskFromJob(job, type);
    } on NotFoundException {
      return null;
    } on ServerException catch (e) {
      if (e.message.toLowerCase().contains('not found')) return null;
      rethrow;
    }
  }

  Future<void> updateStatus({
    required String shipmentId,
    required ShipmentStatus newStatus,
    String? note,
    String? apiStatus,
  }) async {
    final status = apiStatus ?? _mapShipmentStatusToApi(newStatus);
    await _api.postJson(
      '/driver/jobs/$shipmentId/scan',
      body: {
        'status': status,
        if (note != null) 'note': note,
      },
    );
  }

  Future<void> acceptJob(String cnNo) async {
    await _api.postJson('/driver/jobs/$cnNo/accept');
  }

  Future<bool> openNavigation(String cnNo) async {
    final json = await _api.getJson('/driver/jobs/$cnNo/navigate');
    final url = json['url'] as String?;
    if (url == null || url.isEmpty) return false;
    final jobJson = await _api.getJson('/driver/jobs/$cnNo');
    final job = jobJson['job'] as Map<String, dynamic>?;
    final lat = (job?['lat'] as num?)?.toDouble();
    final lng = (job?['lng'] as num?)?.toDouble();
    final address = job?['address'] as String?;
    return GoogleMapsLauncher.openDirections(
      lat: lat,
      lng: lng,
      address: address ?? url,
    );
  }

  DriverTask _taskFromJob(Map<String, dynamic> job, DriverTaskType type) {
    final cnNo = job['cnNo']?.toString() ?? '';
    final fmsStatus = job['status']?.toString() ?? '';
    final lastMobile = job['lastMobileStatus']?.toString();
    final nextScans = (job['nextScans'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final shipment = Shipment(
      id: cnNo,
      trackingNumber: cnNo,
      customerId: 'fms',
      originAddress: type == DriverTaskType.pickup
          ? (job['address']?.toString() ?? '')
          : (job['originLoc']?.toString() ?? ''),
      originCity: job['originLoc']?.toString() ?? '',
      originProvince: 'Sabah',
      originZone: job['originLoc']?.toString() ?? '',
      originLat: type == DriverTaskType.pickup
          ? (job['lat'] as num?)?.toDouble()
          : null,
      originLng: type == DriverTaskType.pickup
          ? (job['lng'] as num?)?.toDouble()
          : null,
      destinationAddress: type == DriverTaskType.delivery
          ? (job['address']?.toString() ?? '')
          : (job['destLoc']?.toString() ?? ''),
      destinationCity: job['destLoc']?.toString() ?? '',
      destinationProvince: 'Sabah',
      destinationZone: job['destLoc']?.toString() ?? '',
      destinationLat: type == DriverTaskType.delivery
          ? (job['lat'] as num?)?.toDouble()
          : null,
      destinationLng: type == DriverTaskType.delivery
          ? (job['lng'] as num?)?.toDouble()
          : null,
      weightKg: (job['weight'] as num?)?.toDouble() ?? 0,
      packageCount: (job['pieces'] as num?)?.toInt() ?? 1,
      status: _mapFmsToShipmentStatus(fmsStatus, lastMobile, type),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      packageDescription: job['recipientName']?.toString(),
      pickupHubWorkerId: type == DriverTaskType.pickup ? 'api' : null,
      deliveryHubWorkerId: type == DriverTaskType.delivery ? 'api' : null,
    );
    return DriverTask(
      shipment: shipment,
      type: type,
      lastMobileStatus: lastMobile,
      nextScans: nextScans,
    );
  }

  ShipmentStatus _mapFmsToShipmentStatus(
    String fms,
    String? lastMobile,
    DriverTaskType type,
  ) {
    final code = (lastMobile ?? fms).toUpperCase();
    return switch (code) {
      IposbStatusMap.accept || 'BDE' => ShipmentStatus.assigned,
      IposbStatusMap.pickedUp => ShipmentStatus.pickedUp,
      IposbStatusMap.arrivedHub ||
      IposbStatusMap.atHub ||
      'INB' ||
      'GWD' =>
        ShipmentStatus.atOriginHub,
      IposbStatusMap.sorted => ShipmentStatus.sorting,
      IposbStatusMap.storekeeper => ShipmentStatus.atDestinationHub,
      IposbStatusMap.outForDelivery || IposbStatusMap.withCourier =>
        ShipmentStatus.outForDelivery,
      IposbStatusMap.delivered || 'PCC' || 'PFP' || 'PCB' =>
        ShipmentStatus.delivered,
      IposbStatusMap.undelivered || IposbStatusMap.overnight =>
        ShipmentStatus.failed,
      'MNF' => ShipmentStatus.inTransit,
      _ => type == DriverTaskType.pickup
          ? ShipmentStatus.assigned
          : ShipmentStatus.outForDelivery,
    };
  }

  String _mapShipmentStatusToApi(ShipmentStatus status) {
    return switch (status) {
      ShipmentStatus.assigned || ShipmentStatus.pickupScheduled =>
        IposbStatusMap.accept,
      ShipmentStatus.pickedUp => IposbStatusMap.pickedUp,
      ShipmentStatus.atOriginDropPoint || ShipmentStatus.atOriginHub =>
        IposbStatusMap.arrivedHub,
      ShipmentStatus.sorting => IposbStatusMap.sorted,
      ShipmentStatus.atDestinationHub ||
      ShipmentStatus.atDestinationDropPoint =>
        IposbStatusMap.storekeeper,
      ShipmentStatus.outForDelivery => IposbStatusMap.outForDelivery,
      ShipmentStatus.delivered => IposbStatusMap.delivered,
      ShipmentStatus.failed => IposbStatusMap.undelivered,
      _ => IposbStatusMap.accept,
    };
  }
}
