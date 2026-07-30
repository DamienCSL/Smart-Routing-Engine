import '../../../../core/utils/result.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../entities/driver_task.dart';

abstract class DriverTaskRepository {
  Future<Result<List<DriverTask>>> getPickupTasks();

  Future<Result<List<DriverTask>>> getDeliveryTasks();

  Stream<List<DriverTask>> watchPickupTasks();

  Stream<List<DriverTask>> watchDeliveryTasks();

  Future<Result<DriverTask?>> getTaskByShipmentId(String shipmentId);

  Future<Result<void>> updateStatus({
    required String shipmentId,
    required ShipmentStatus newStatus,
    String? note,
  });
}
