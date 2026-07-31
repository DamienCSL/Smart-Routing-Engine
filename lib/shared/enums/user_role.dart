/// System roles mapped to `roles` table and Supabase Auth metadata.
enum UserRole {
  customer('customer', 'Customer'),
  hubWorker('hub_worker', 'Hub Worker'),
  /// Field driver — uses hub-worker ops shell against `/driver/*`.
  driver('driver', 'Driver'),
  /// Mobile dispatcher — assign desk against `/dispatch/*` (not FMS web).
  dispatcher('dispatcher', 'Dispatcher'),
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

  /// True if this role uses the hub-worker ops shell (`/driver/*`).
  bool get isHubOps =>
      this == UserRole.hubWorker ||
      this == UserRole.driver ||
      this == UserRole.admin;

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.customer,
    );
  }
}
