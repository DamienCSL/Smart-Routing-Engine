import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../../domain/entities/storekeeper_task.dart';
import '../../domain/repositories/storekeeper_repository.dart';
import '../datasources/storekeeper_remote_datasource.dart';

class StorekeeperRepositoryImpl implements StorekeeperRepository {
  StorekeeperRepositoryImpl(this._dataSource);

  final StorekeeperRemoteDataSource _dataSource;

  @override
  Future<Result<List<StorekeeperTask>>> getHubTasks() async {
    try {
      return Success(await _dataSource.getHubTasks());
    } on ServerException catch (e) {
      return Error(e.message);
    } on AuthException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Stream<List<StorekeeperTask>> watchHubTasks() {
    return _dataSource.watchHubTasks();
  }

  @override
  Future<Result<StorekeeperTask?>> getTaskByShipmentId(String shipmentId) async {
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
