import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../shipment/data/models/shipment_model.dart';
import '../../../shipment/domain/entities/shipment.dart';
import '../../domain/entities/dispatcher_profile.dart';
import '../../domain/entities/zone_driver_summary.dart';

class DispatcherRemoteDataSource {
  DispatcherRemoteDataSource(this._client);

  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 20);

  Future<DispatcherProfile> getCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Not authenticated');
    }

    try {
      final row = await _client
          .from('dispatchers')
          .select('id, zone, hub_id')
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(_timeout);

      final id = row?['id'] as String?;
      if (id == null) {
        throw const ServerException(
          'No dispatcher profile found. '
          'Sign in with dispatcher.kk@iposb.demo or dispatcher.sandakan@iposb.demo',
        );
      }

      return DispatcherProfile(
        id: id,
        zone: row!['zone'] as String,
        hubId: row['hub_id'] as String?,
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading dispatcher profile timed out.');
    }
  }

  Future<List<Shipment>> getZoneShipments() async {
    final profile = await getCurrentProfile();
    final zone = profile.zone;

    try {
      final data = await _client
          .from('shipments')
          .select()
          .or('origin_zone.eq.$zone,destination_zone.eq.$zone')
          .order('updated_at', ascending: false)
          .timeout(_timeout);

      final shipments = (data as List<dynamic>)
          .map((row) =>
              ShipmentModel.fromJson(row as Map<String, dynamic>).toEntity())
          .toList();

      AppLogger.info(
        'Dispatcher zone=$zone shipments=${shipments.length}',
      );
      return shipments;
    } on PostgrestException catch (e) {
      AppLogger.error('Dispatcher getZoneShipments failed', e);
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading zone shipments timed out.');
    }
  }

  Stream<List<Shipment>> watchZoneShipments() async* {
    Future<List<Shipment>> load() => getZoneShipments();

    yield await load();

    yield* _client
        .from('shipments')
        .stream(primaryKey: ['id'])
        .asyncMap((_) => load());
  }

  Future<List<ZoneDriverSummary>> getZoneDrivers() async {
    final profile = await getCurrentProfile();

    try {
      final data = await _client
          .from('drivers')
          .select('id, zone, vehicle_type, vehicle_plate, is_available')
          .eq('zone', profile.zone)
          .order('is_available', ascending: false)
          .timeout(_timeout);

      return (data as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        return ZoneDriverSummary(
          id: map['id'] as String,
          zone: map['zone'] as String,
          vehicleType: map['vehicle_type'] as String,
          vehiclePlate: map['vehicle_plate'] as String,
          isAvailable: map['is_available'] as bool? ?? false,
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading zone drivers timed out.');
    }
  }
}
