import '../../../../core/utils/result.dart';
import '../../../shipment/domain/entities/shipment.dart';
import '../entities/dispatcher_profile.dart';
import '../entities/zone_driver_summary.dart';

abstract class DispatcherRepository {
  Future<Result<DispatcherProfile>> getCurrentProfile();

  Future<Result<List<Shipment>>> getZoneShipments();

  Stream<List<Shipment>> watchZoneShipments();

  Future<Result<List<ZoneDriverSummary>>> getZoneDrivers();
}
