import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../core/errors/exceptions.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../../../driver/domain/entities/driver_task.dart';
import '../../../shipment/data/models/shipment_model.dart';

/// Profile + tasks for the merged hub-worker role.
class HubWorkerRemoteDataSource {
  HubWorkerRemoteDataSource(this._client);

  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 20);

  Future<({String id, String hubId, List<String> preferredZones})>
      getCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Not authenticated');
    }

    try {
      final row = await _client
          .from('hub_workers')
          .select('id, hub_id, preferred_zones')
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(_timeout);

      final id = row?['id'] as String?;
      final hubId = row?['hub_id'] as String?;
      if (id == null || hubId == null) {
        throw const ServerException(
          'No hub worker profile found. '
          'Sign in as hub.kk@iposb.demo or hub.sandakan@iposb.demo '
          '(or re-run demo_staff.sql after 011_hub_workers.sql).',
        );
      }

      final zonesRaw = row?['preferred_zones'];
      final zones = zonesRaw is List
          ? zonesRaw.map((e) => e.toString()).toList()
          : <String>[];

      return (id: id, hubId: hubId, preferredZones: zones);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading hub worker profile timed out.');
    }
  }

  Future<List<DriverTask>> getTasks({required DriverTaskType type}) async {
    final profile = await getCurrentProfile();
    final column = type == DriverTaskType.pickup
        ? 'pickup_hub_worker_id'
        : 'delivery_hub_worker_id';

    try {
      final data = await _client
          .from('shipments')
          .select()
          .eq(column, profile.id)
          .order('created_at', ascending: false)
          .timeout(_timeout);

      return (data as List<dynamic>)
          .map((row) {
            final shipment =
                ShipmentModel.fromJson(row as Map<String, dynamic>).toEntity();
            return DriverTask(shipment: shipment, type: type);
          })
          .where(_isVisibleForType)
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading hub worker tasks timed out.');
    }
  }

  Stream<List<DriverTask>> watchTasks({required DriverTaskType type}) async* {
    Future<List<DriverTask>> load() => getTasks(type: type);
    yield await load();
    yield* _client
        .from('shipments')
        .stream(primaryKey: ['id'])
        .asyncMap((_) => load());
  }

  Future<DriverTask?> getTaskByShipmentId(String shipmentId) async {
    final profile = await getCurrentProfile();

    try {
      final data = await _client
          .from('shipments')
          .select()
          .eq('id', shipmentId)
          .maybeSingle()
          .timeout(_timeout);

      if (data == null) return null;

      final shipment = ShipmentModel.fromJson(data).toEntity();
      if (shipment.pickupHubWorkerId == profile.id) {
        return DriverTask(shipment: shipment, type: DriverTaskType.pickup);
      }
      if (shipment.deliveryHubWorkerId == profile.id) {
        return DriverTask(shipment: shipment, type: DriverTaskType.delivery);
      }
      return null;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading task timed out.');
    }
  }

  Future<void> updateStatus({
    required String shipmentId,
    required ShipmentStatus newStatus,
    String? note,
  }) async {
    try {
      final response = await _client
          .rpc(
            'hub_worker_update_shipment_status',
            params: {
              'p_shipment_id': shipmentId,
              'p_new_status': newStatus.value,
              'p_note': note,
            },
          )
          .timeout(_timeout);

      if (response is Map && response['ok'] != true) {
        throw ServerException(response['error']?.toString() ?? 'Update failed');
      }
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Updating status timed out.');
    }
  }

  bool _isVisibleForType(DriverTask task) {
    if (task.type == DriverTaskType.pickup) {
      return const {
        ShipmentStatus.assigned,
        ShipmentStatus.pickupScheduled,
        ShipmentStatus.pickedUp,
      }.contains(task.status);
    }

    return const {
      ShipmentStatus.atOriginDropPoint,
      ShipmentStatus.atOriginHub,
      ShipmentStatus.sorting,
      ShipmentStatus.inTransit,
      ShipmentStatus.atDestinationHub,
      ShipmentStatus.atDestinationDropPoint,
      ShipmentStatus.outForDelivery,
    }.contains(task.status);
  }
}
