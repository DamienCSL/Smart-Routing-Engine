import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../../../shipment/data/models/shipment_model.dart';
import '../../domain/entities/drop_point_task.dart';

class DropPointRemoteDataSource {
  DropPointRemoteDataSource(this._client);

  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 20);

  Future<String> getCurrentDropPointId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Not authenticated');
    }

    try {
      final row = await _client
          .from('drop_points')
          .select('id, code, name')
          .eq('operator_id', userId)
          .maybeSingle()
          .timeout(_timeout);

      final id = row?['id'] as String?;
      if (id == null) {
        throw const ServerException(
          'No drop point linked to this account. '
          'Sign in as droppoint.origin@iposb.demo or droppoint.dest@iposb.demo '
          'after running demo_drop_points.sql.',
        );
      }

      AppLogger.info(
        'DropPoint id=$id code=${row?['code']} name=${row?['name']}',
      );
      return id;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading drop point profile timed out.');
    }
  }

  Future<List<DropPointTask>> getTasks({
    required DropPointQueueType queueType,
  }) async {
    final dpId = await getCurrentDropPointId();
    final column = queueType == DropPointQueueType.originIntake
        ? 'origin_drop_point_id'
        : 'destination_drop_point_id';

    try {
      final data = await _client
          .from('shipments')
          .select()
          .eq(column, dpId)
          .order('updated_at', ascending: false)
          .timeout(_timeout);

      final tasks = (data as List<dynamic>)
          .map((row) {
            final shipment =
                ShipmentModel.fromJson(row as Map<String, dynamic>).toEntity();
            return DropPointTask(shipment: shipment, queueType: queueType);
          })
          .where(_isVisible)
          .toList();

      AppLogger.info(
        'DropPoint getTasks queue=${queueType.value} dp=$dpId '
        'rows=${(data).length} visible=${tasks.length}',
      );
      return tasks;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading drop point tasks timed out.');
    }
  }

  Stream<List<DropPointTask>> watchTasks({
    required DropPointQueueType queueType,
  }) async* {
    Future<List<DropPointTask>> load() => getTasks(queueType: queueType);
    yield await load();
    yield* _client
        .from('shipments')
        .stream(primaryKey: ['id'])
        .asyncMap((_) => load());
  }

  Future<DropPointTask?> getTaskByShipmentId(String shipmentId) async {
    final dpId = await getCurrentDropPointId();

    try {
      final data = await _client
          .from('shipments')
          .select()
          .eq('id', shipmentId)
          .maybeSingle()
          .timeout(_timeout);

      if (data == null) return null;

      final shipment = ShipmentModel.fromJson(data).toEntity();
      if (shipment.originDropPointId == dpId) {
        return DropPointTask(
          shipment: shipment,
          queueType: DropPointQueueType.originIntake,
        );
      }
      if (shipment.destinationDropPointId == dpId) {
        return DropPointTask(
          shipment: shipment,
          queueType: DropPointQueueType.destinationIntake,
        );
      }
      return null;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading drop point task timed out.');
    }
  }

  Future<void> updateStatus({
    required String shipmentId,
    required ShipmentStatus newStatus,
    String? note,
  }) async {
    try {
      AppLogger.info('DropPoint: $shipmentId → ${newStatus.value}');
      final response = await _client
          .rpc(
            'drop_point_update_shipment_status',
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
      throw const ServerException('Updating drop point status timed out.');
    }
  }

  bool _isVisible(DropPointTask task) {
    if (task.queueType == DropPointQueueType.originIntake) {
      return task.status == ShipmentStatus.atOriginDropPoint;
    }
    return task.status == ShipmentStatus.inTransit ||
        task.status == ShipmentStatus.atDestinationHub ||
        task.status == ShipmentStatus.atDestinationDropPoint;
  }
}
