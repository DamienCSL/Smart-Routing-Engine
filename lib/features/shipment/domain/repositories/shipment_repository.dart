import '../../../../core/utils/result.dart';
import '../entities/create_shipment_request.dart';
import '../entities/shipment.dart';
import '../entities/shipment_history_entry.dart';

abstract class ShipmentRepository {
  /// Creates a shipment with tracking number + initial history.
  /// Leaves a hook for the Assignment Engine (Phase 4).
  Future<Result<Shipment>> createShipment(CreateShipmentRequest request);

  Future<Result<List<Shipment>>> getCustomerShipments(String customerId);

  Future<Result<Shipment>> getShipmentById(String id);

  Future<Result<List<ShipmentHistoryEntry>>> getShipmentHistory(String shipmentId);

  /// Realtime stream of the signed-in customer's shipments.
  Stream<List<Shipment>> watchCustomerShipments(String customerId);
}
