import '../../../../core/utils/result.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../entities/storekeeper_task.dart';

abstract class StorekeeperRepository {
  Future<Result<List<StorekeeperTask>>> getHubTasks();

  Stream<List<StorekeeperTask>> watchHubTasks();

  Future<Result<StorekeeperTask?>> getTaskByShipmentId(String shipmentId);

  Future<Result<void>> updateStatus({
    required String shipmentId,
    required ShipmentStatus newStatus,
    String? note,
  });
}
