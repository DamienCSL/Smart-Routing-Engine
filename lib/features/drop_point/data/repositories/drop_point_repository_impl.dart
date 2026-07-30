import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../../domain/entities/drop_point_task.dart';
import '../../domain/repositories/drop_point_repository.dart';
import '../datasources/drop_point_remote_datasource.dart';

class DropPointRepositoryImpl implements DropPointRepository {
  DropPointRepositoryImpl(this._dataSource);

  final DropPointRemoteDataSource _dataSource;

  @override
  Future<Result<List<DropPointTask>>> getOriginIntakeTasks() async {
    try {
      return Success(
        await _dataSource.getTasks(queueType: DropPointQueueType.originIntake),
      );
    } on ServerException catch (e) {
      return Error(e.message);
    } on AuthException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Future<Result<List<DropPointTask>>> getDestinationIntakeTasks() async {
    try {
      return Success(
        await _dataSource.getTasks(
          queueType: DropPointQueueType.destinationIntake,
        ),
      );
    } on ServerException catch (e) {
      return Error(e.message);
    } on AuthException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Stream<List<DropPointTask>> watchOriginIntakeTasks() {
    return _dataSource.watchTasks(queueType: DropPointQueueType.originIntake);
  }

  @override
  Stream<List<DropPointTask>> watchDestinationIntakeTasks() {
    return _dataSource.watchTasks(
      queueType: DropPointQueueType.destinationIntake,
    );
  }

  @override
  Future<Result<DropPointTask?>> getTaskByShipmentId(String shipmentId) async {
    try {
      return Success(await _dataSource.getTaskByShipmentId(shipmentId));
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
