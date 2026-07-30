import 'package:equatable/equatable.dart';

/// Result returned by the Assignment Engine after auto-routing.
class AssignmentResult extends Equatable {
  const AssignmentResult({
    required this.ok,
    this.skipped = false,
    this.message,
    this.error,
    this.eta,
    this.missingStaff = const [],
    this.assignments = const {},
    this.steps = const [],
  });

  factory AssignmentResult.fromJson(Map<String, dynamic> json) {
    final missing = json['missing_staff'];
    final assignments = json['assignments'];
    final steps = json['steps'];

    return AssignmentResult(
      ok: json['ok'] as bool? ?? false,
      skipped: json['skipped'] as bool? ?? false,
      message: json['message'] as String?,
      error: json['error'] as String?,
      eta: json['eta'] != null ? DateTime.tryParse(json['eta'] as String) : null,
      missingStaff: missing is List
          ? missing.map((e) => e.toString()).toList()
          : const [],
      assignments: assignments is Map
          ? assignments.map((k, v) => MapEntry(k.toString(), v?.toString()))
          : const {},
      steps: steps is List
          ? steps
              .whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
              .toList()
          : const [],
    );
  }

  final bool ok;
  final bool skipped;
  final String? message;
  final String? error;
  final DateTime? eta;
  final List<String> missingStaff;
  final Map<String, String?> assignments;
  final List<Map<String, dynamic>> steps;

  @override
  List<Object?> get props => [ok, skipped, error, eta, missingStaff];
}
