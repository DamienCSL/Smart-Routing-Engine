import '../../../core/utils/result.dart';
import '../../shipment/domain/entities/shipment.dart';
import 'entities/assignment_result.dart';

/// Intelligent (rules-based) logistics assignment engine.
abstract class AssignmentEngine {
  /// Runs the full assignment pipeline for a newly created shipment.
  Future<Result<AssignmentResult>> assign(Shipment shipment);
}
