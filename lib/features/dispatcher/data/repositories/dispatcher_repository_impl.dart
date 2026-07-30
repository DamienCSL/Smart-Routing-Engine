import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../../shipment/domain/entities/shipment.dart';
import '../../domain/entities/dispatcher_profile.dart';
import '../../domain/entities/zone_driver_summary.dart';
import '../../domain/repositories/dispatcher_repository.dart';
import '../datasources/dispatcher_remote_datasource.dart';

class DispatcherRepositoryImpl implements DispatcherRepository {
  DispatcherRepositoryImpl(this._dataSource);

  final DispatcherRemoteDataSource _dataSource;

  @override
  Future<Result<DispatcherProfile>> getCurrentProfile() async {
    try {
      return Success(await _dataSource.getCurrentProfile());
    } on ServerException catch (e) {
      return Error(e.message);
    } on AuthException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Future<Result<List<Shipment>>> getZoneShipments() async {
    try {
      return Success(await _dataSource.getZoneShipments());
    } on ServerException catch (e) {
      return Error(e.message);
    } on AuthException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Stream<List<Shipment>> watchZoneShipments() {
    return _dataSource.watchZoneShipments();
  }

  @override
  Future<Result<List<ZoneDriverSummary>>> getZoneDrivers() async {
    try {
      return Success(await _dataSource.getZoneDrivers());
    } on ServerException catch (e) {
      return Error(e.message);
    } on AuthException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }
}
