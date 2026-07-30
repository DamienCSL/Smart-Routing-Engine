import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../../../shipment/data/models/shipment_model.dart';
import '../../domain/entities/driver_task.dart';

class DriverRemoteDataSource {
  DriverRemoteDataSource(this._client);

  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 20);

  Future<String> getCurrentDriverId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Not authenticated');
    }

    try {
      final row = await _client
          .from('drivers')
          .select('id, zone')
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(_timeout);

      final id = row?['id'] as String?;
      if (id == null) {
        throw const ServerException(
          'No driver profile found for this account. '
          'Sign in with a seeded driver (e.g. driver.pickup@iposb.demo).',
        );
      }

      AppLogger.info(
        'Driver profile id=$id zone=${row?['zone']} user=$userId',
      );
      return id;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading driver profile timed out.');
    }
  }

  Future<List<DriverTask>> getTasks({
    required DriverTaskType type,
  }) async {
    final driverId = await getCurrentDriverId();
    final column =
        type == DriverTaskType.pickup ? 'pickup_driver_id' : 'delivery_driver_id';

    try {
      final data = await _client
          .from('shipments')
          .select()
          .eq(column, driverId)
          .order('created_at', ascending: false)
          .timeout(_timeout);

      final tasks = (data as List<dynamic>)
          .map((row) {
            final shipment =
                ShipmentModel.fromJson(row as Map<String, dynamic>).toEntity();
            return DriverTask(shipment: shipment, type: type);
          })
          .where(_isVisibleForType)
          .toList();

      AppLogger.info(
        'Driver getTasks type=${type.value} driverId=$driverId '
        'rows=${(data).length} visible=${tasks.length}',
      );

      return tasks;
    } on PostgrestException catch (e) {
      // Empty due to missing RLS often looks like success []; real errors throw.
      AppLogger.error('Driver getTasks failed', e);
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading driver tasks timed out.');
    }
  }

  /// Reliable watch: REST load first, then re-fetch on any shipments change.
  ///
  /// Avoids Supabase `.stream().eq(...)` quirks that can emit an empty list
  /// even when assigned rows exist.
  Stream<List<DriverTask>> watchTasks({
    required DriverTaskType type,
  }) async* {
    Future<List<DriverTask>> load() => getTasks(type: type);

    yield await load();

    yield* _client
        .from('shipments')
        .stream(primaryKey: ['id'])
        .asyncMap((_) => load());
  }

  Future<DriverTask?> getTaskByShipmentId(String shipmentId) async {
    final driverId = await getCurrentDriverId();

    try {
      final data = await _client
          .from('shipments')
          .select()
          .eq('id', shipmentId)
          .maybeSingle()
          .timeout(_timeout);

      if (data == null) {
        AppLogger.info(
          'Driver getTaskByShipmentId: no row (RLS or missing) id=$shipmentId',
        );
        return null;
      }

      final shipment = ShipmentModel.fromJson(data).toEntity();
      if (shipment.pickupDriverId == driverId) {
        return DriverTask(shipment: shipment, type: DriverTaskType.pickup);
      }
      if (shipment.deliveryDriverId == driverId) {
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
      AppLogger.info(
        'Driver: updating $shipmentId → ${newStatus.value}',
      );

      final response = await _client
          .rpc(
            'driver_update_shipment_status',
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
