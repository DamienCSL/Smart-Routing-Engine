/// Dispatcher staff profile linked to `dispatchers` / `/dispatcher/me`.
class DispatcherProfile {
  const DispatcherProfile({
    required this.id,
    required this.zone,
    this.hubId,
    this.code,
    this.fullName,
    this.phone,
    this.preferredZones = const [],
  });

  final String id;
  final String zone;

  /// Branch / hub code when available.
  final String? hubId;
  final String? code;
  final String? fullName;
  final String? phone;
  final List<String> preferredZones;
}
