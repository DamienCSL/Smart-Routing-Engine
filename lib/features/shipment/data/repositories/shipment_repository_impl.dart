import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/result.dart';
import '../../../assignment_engine/domain/assignment_engine.dart';
import '../../domain/entities/create_shipment_request.dart';
import '../../domain/entities/shipment.dart';
import '../../domain/entities/shipment_history_entry.dart';
import '../../domain/repositories/shipment_repository.dart';
import '../../domain/services/tracking_number_service.dart';
import '../datasources/shipment_remote_datasource.dart';

class ShipmentRepositoryImpl implements ShipmentRepository {
  ShipmentRepositoryImpl({
    required ShipmentRemoteDataSource dataSource,
    required AssignmentEngine assignmentEngine,
    required String Function() currentUserId,
  })  : _dataSource = dataSource,
        _assignmentEngine = assignmentEngine,
        _currentUserId = currentUserId;

  final ShipmentRemoteDataSource _dataSource;
  final AssignmentEngine _assignmentEngine;
  final String Function() _currentUserId;

  @override
  Future<Result<Shipment>> createShipment(CreateShipmentRequest request) async {
    try {
      final customerId = _currentUserId();
      if (customerId.isEmpty) {
        return const Error('Not authenticated');
      }

      final trackingNumber = TrackingNumberService.generate();
      final model = await _dataSource.createShipment(
        customerId: customerId,
        trackingNumber: trackingNumber,
        request: request,
      );

      final shipment = model.toEntity();

      final assignment = await _assignmentEngine.assign(shipment);
      assignment.when(
        success: (result) {
          AppLogger.info(
            'Assignment complete for ${shipment.trackingNumber} '
            '(missing staff: ${result.missingStaff})',
          );
        },
        failure: (message) {
          AppLogger.error(
            'Assignment engine failed for ${shipment.trackingNumber}: $message',
          );
        },
      );

      final refreshed = await _dataSource.getShipmentById(shipment.id);
      return Success(refreshed.toEntity());
    } on ServerException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Future<Result<List<Shipment>>> getCustomerShipments(String customerId) async {
    try {
      final models = await _dataSource.getCustomerShipments(customerId);
      return Success(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Future<Result<Shipment>> getShipmentById(String id) async {
    try {
      final model = await _dataSource.getShipmentById(id);
      return Success(model.toEntity());
    } on ServerException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Future<Result<List<ShipmentHistoryEntry>>> getShipmentHistory(
    String shipmentId,
  ) async {
    try {
      final models = await _dataSource.getShipmentHistory(shipmentId);
      return Success(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Stream<List<Shipment>> watchCustomerShipments(String customerId) {
    return _dataSource.watchCustomerShipments(customerId).map(
          (models) => models.map((m) => m.toEntity()).toList(),
        );
  }
}
