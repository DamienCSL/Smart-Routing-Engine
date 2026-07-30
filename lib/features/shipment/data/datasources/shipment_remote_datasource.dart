import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/create_shipment_request.dart';
import '../models/shipment_model.dart';

class ShipmentRemoteDataSource {
  ShipmentRemoteDataSource(this._client);

  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 20);

  Future<ShipmentModel> createShipment({
    required String customerId,
    required String trackingNumber,
    required CreateShipmentRequest request,
  }) async {
    try {
      AppLogger.info('Shipment: creating $trackingNumber for $customerId');

      final inserted = await _client
          .from('shipments')
          .insert(
            ShipmentModel.toInsertJson(
              trackingNumber: trackingNumber,
              customerId: customerId,
              originAddress: request.originAddress,
              originCity: request.originCity,
              originProvince: request.originProvince,
              originZone: request.originZone,
              originLat: request.originLat,
              originLng: request.originLng,
              destinationAddress: request.destinationAddress,
              destinationCity: request.destinationCity,
              destinationProvince: request.destinationProvince,
              destinationZone: request.destinationZone,
              destinationLat: request.destinationLat,
              destinationLng: request.destinationLng,
              weightKg: request.weightKg,
              packageCount: request.packageCount,
              packageDescription: request.packageDescription,
            ),
          )
          .select()
          .single()
          .timeout(_timeout);

      final shipment = ShipmentModel.fromJson(inserted);

      // Initial shipment_history row is created by DB trigger
      // (004_shipment_history_trigger.sql) to avoid RLS insert issues.

      AppLogger.info('Shipment: created ${shipment.id}');
      return shipment;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Creating shipment timed out.');
    }
  }

  Future<List<ShipmentModel>> getCustomerShipments(String customerId) async {
    try {
      final data = await _client
          .from('shipments')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false)
          .timeout(_timeout);

      return (data as List<dynamic>)
          .map((row) => ShipmentModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading shipments timed out.');
    }
  }

  Future<ShipmentModel> getShipmentById(String id) async {
    try {
      final data = await _client
          .from('shipments')
          .select()
          .eq('id', id)
          .single()
          .timeout(_timeout);

      return ShipmentModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading shipment timed out.');
    }
  }

  Future<List<ShipmentHistoryModel>> getShipmentHistory(
    String shipmentId,
  ) async {
    try {
      final data = await _client
          .from('shipment_history')
          .select()
          .eq('shipment_id', shipmentId)
          .order('created_at', ascending: true)
          .timeout(_timeout);

      return (data as List<dynamic>)
          .map(
            (row) =>
                ShipmentHistoryModel.fromJson(row as Map<String, dynamic>),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading shipment history timed out.');
    }
  }

  Stream<List<ShipmentModel>> watchCustomerShipments(String customerId) {
    return _client
        .from('shipments')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows.map(ShipmentModel.fromJson).toList(),
        );
  }
}
