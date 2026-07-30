import '../../../core/errors/exceptions.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/result.dart';
import '../../shipment/domain/entities/shipment.dart';
import '../domain/assignment_engine.dart';
import '../domain/entities/assignment_result.dart';
import 'datasources/assignment_remote_datasource.dart';

/// Rules-based assignment engine — orchestrates the Supabase RPC pipeline.
class RoutingAssignmentEngine implements AssignmentEngine {
  RoutingAssignmentEngine(this._dataSource);

  final AssignmentRemoteDataSource _dataSource;

  @override
  Future<Result<AssignmentResult>> assign(Shipment shipment) async {
    try {
      AppLogger.info(
        'AssignmentEngine pipeline for ${shipment.trackingNumber}: '
        '${shipment.originZone} → ${shipment.destinationZone}',
      );

      // Pipeline (executed inside RPC):
      // Find Pickup Zone → Dispatcher → Pickup Driver → Origin DP/Hub →
      // Storekeeper → Sorting Hub → Dest Hub/DP → Delivery Dispatcher/Driver →
      // Calculate ETA → History → Notifications
      final result = await _dataSource.runAssignmentEngine(shipment.id);

      if (!result.ok) {
        return Error(result.error ?? 'Assignment engine failed');
      }

      return Success(result);
    } on ServerException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }
}
