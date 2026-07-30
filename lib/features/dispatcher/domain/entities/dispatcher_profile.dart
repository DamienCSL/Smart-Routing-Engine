/// Dispatcher staff profile linked to `dispatchers` table.
class DispatcherProfile {
  const DispatcherProfile({
    required this.id,
    required this.zone,
    this.hubId,
  });

  final String id;
  final String zone;
  final String? hubId;
}
