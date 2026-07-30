import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../../domain/entities/driver_task.dart';
import '../../domain/repositories/driver_task_repository.dart';
import '../datasources/driver_remote_datasource.dart';

class DriverTaskRepositoryImpl implements DriverTaskRepository {
  DriverTaskRepositoryImpl(this._dataSource);

  final DriverRemoteDataSource _dataSource;

  @override
  Future<Result<List<DriverTask>>> getPickupTasks() async {
    try {
      final tasks = await _dataSource.getTasks(type: DriverTaskType.pickup);
      return Success(tasks);
    } on ServerException catch (e) {
      return Error(e.message);
    } on AuthException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Future<Result<List<DriverTask>>> getDeliveryTasks() async {
    try {
      final tasks = await _dataSource.getTasks(type: DriverTaskType.delivery);
      return Success(tasks);
    } on ServerException catch (e) {
      return Error(e.message);
    } on AuthException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Stream<List<DriverTask>> watchPickupTasks() {
    return _dataSource.watchTasks(type: DriverTaskType.pickup);
  }

  @override
  Stream<List<DriverTask>> watchDeliveryTasks() {
    return _dataSource.watchTasks(type: DriverTaskType.delivery);
  }

  @override
  Future<Result<DriverTask?>> getTaskByShipmentId(String shipmentId) async {
    try {
      final task = await _dataSource.getTaskByShipmentId(shipmentId);
      return Success(task);
    } on ServerException catch (e) {
      return Error(e.message);
    } on AuthException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Future<Result<void>> updateStatus({
    required String shipmentId,
    required ShipmentStatus newStatus,
    String? note,
  }) async {
    try {
      await _dataSource.updateStatus(
        shipmentId: shipmentId,
        newStatus: newStatus,
        note: note,
      );
      return const Success(null);
    } on ServerException catch (e) {
      return Error(e.message);
    } on AuthException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }
}
