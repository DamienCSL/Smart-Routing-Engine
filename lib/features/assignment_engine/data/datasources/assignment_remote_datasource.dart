import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/assignment_result.dart';

class AssignmentRemoteDataSource {
  AssignmentRemoteDataSource(this._client);

  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 30);

  Future<AssignmentResult> runAssignmentEngine(String shipmentId) async {
    try {
      AppLogger.info('AssignmentEngine: starting for $shipmentId');

      final response = await _client
          .rpc(
            'run_assignment_engine',
            params: {'p_shipment_id': shipmentId},
          )
          .timeout(_timeout);

      if (response is! Map<String, dynamic>) {
        throw ServerException(
          'Unexpected assignment response: ${response.runtimeType}',
        );
      }

      final result = AssignmentResult.fromJson(response);
      AppLogger.info(
        'AssignmentEngine: ok=${result.ok} skipped=${result.skipped} '
        'missing=${result.missingStaff} error=${result.error}',
      );
      for (final step in result.steps) {
        AppLogger.info('AssignmentEngine step: $step');
      }
      return result;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Assignment engine timed out.');
    }
  }
}
