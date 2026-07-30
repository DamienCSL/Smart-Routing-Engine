import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../../../shipment/data/models/shipment_model.dart';
import '../../domain/entities/storekeeper_task.dart';

class StorekeeperRemoteDataSource {
  StorekeeperRemoteDataSource(this._client);

  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 20);

  Future<({String id, String hubId})> getCurrentStorekeeper() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Not authenticated');
    }

    try {
      final row = await _client
          .from('storekeepers')
          .select('id, hub_id')
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(_timeout);

      final id = row?['id'] as String?;
      final hubId = row?['hub_id'] as String?;
      if (id == null || hubId == null) {
        throw const ServerException(
          'No storekeeper profile found. '
          'Sign in as storekeeper.origin@iposb.demo',
        );
      }

      AppLogger.info('Storekeeper id=$id hub=$hubId');
      return (id: id, hubId: hubId);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading storekeeper profile timed out.');
    }
  }

  Future<List<StorekeeperTask>> getHubTasks() async {
    final sk = await getCurrentStorekeeper();

    try {
      final data = await _client
          .from('shipments')
          .select()
          .or(
            'storekeeper_id.eq.${sk.id},'
            'origin_hub_id.eq.${sk.hubId},'
            'sorting_hub_id.eq.${sk.hubId},'
            'destination_hub_id.eq.${sk.hubId}',
          )
          .order('updated_at', ascending: false)
          .timeout(_timeout);

      final tasks = (data as List<dynamic>)
          .map((row) {
            final shipment =
                ShipmentModel.fromJson(row as Map<String, dynamic>).toEntity();
            return StorekeeperTask(shipment: shipment);
          })
          .where(_isVisible)
          .toList();

      AppLogger.info(
        'Storekeeper tasks rows=${(data).length} visible=${tasks.length}',
      );
      return tasks;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading hub tasks timed out.');
    }
  }

  Stream<List<StorekeeperTask>> watchHubTasks() async* {
    Future<List<StorekeeperTask>> load() => getHubTasks();
    yield await load();
    yield* _client
        .from('shipments')
        .stream(primaryKey: ['id'])
        .asyncMap((_) => load());
  }

  Future<StorekeeperTask?> getTaskByShipmentId(String shipmentId) async {
    try {
      final data = await _client
          .from('shipments')
          .select()
          .eq('id', shipmentId)
          .maybeSingle()
          .timeout(_timeout);

      if (data == null) return null;
      final task = StorekeeperTask(
        shipment: ShipmentModel.fromJson(data).toEntity(),
      );
      return _isVisible(task) || task.availableActions.isNotEmpty ? task : task;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading storekeeper task timed out.');
    }
  }

  Future<void> updateStatus({
    required String shipmentId,
    required ShipmentStatus newStatus,
    String? note,
  }) async {
    try {
      AppLogger.info('Storekeeper: $shipmentId → ${newStatus.value}');
      final response = await _client
          .rpc(
            'storekeeper_update_shipment_status',
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
      throw const ServerException('Updating storekeeper status timed out.');
    }
  }

  bool _isVisible(StorekeeperTask task) {
    return const {
      ShipmentStatus.atOriginHub,
      ShipmentStatus.sorting,
      ShipmentStatus.inTransit,
      ShipmentStatus.atDestinationHub,
    }.contains(task.status);
  }
}
