/// System roles mapped to `roles` table and Supabase Auth metadata.
enum UserRole {
  customer('customer', 'Customer'),
  hubWorker('hub_worker', 'Hub Worker'),
  /// @Deprecated — aliased to [hubWorker] for old demos / metadata.
  driver('driver', 'Driver (legacy)'),
  /// @Deprecated — aliased to [hubWorker] for old demos / metadata.
  dispatcher('dispatcher', 'Dispatcher (legacy)'),
  dropPoint('drop_point', 'Drop Point'),
  storekeeper('storekeeper', 'Storekeeper'),
  admin('admin', 'Admin');

  const UserRole(this.value, this.label);

  final String value;
  final String label;

  /// Roles shown on the register screen (demo).
  static const List<UserRole> registerChoices = [
    UserRole.customer,
    UserRole.hubWorker,
    UserRole.dropPoint,
    UserRole.storekeeper,
  ];

  /// True if this role uses the hub-worker ops shell.
  bool get isHubOps =>
      this == UserRole.hubWorker ||
      this == UserRole.driver ||
      this == UserRole.dispatcher ||
      this == UserRole.admin;

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.customer,
    );
  }
}
