import '../../../../core/utils/result.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../entities/drop_point_task.dart';

abstract class DropPointRepository {
  Future<Result<List<DropPointTask>>> getOriginIntakeTasks();

  Future<Result<List<DropPointTask>>> getDestinationIntakeTasks();

  Stream<List<DropPointTask>> watchOriginIntakeTasks();

  Stream<List<DropPointTask>> watchDestinationIntakeTasks();

  Future<Result<DropPointTask?>> getTaskByShipmentId(String shipmentId);

  Future<Result<void>> updateStatus({
    required String shipmentId,
    required ShipmentStatus newStatus,
    String? note,
  });
}
