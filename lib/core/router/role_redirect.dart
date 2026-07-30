import '../../shared/enums/user_role.dart';
import '../constants/route_paths.dart';

/// Maps a [UserRole] to its home dashboard route.
String homePathForRole(UserRole role) {
  return switch (role) {
    UserRole.customer => RoutePaths.customerHome,
    UserRole.hubWorker ||
    UserRole.driver ||
    UserRole.dispatcher ||
    UserRole.admin =>
      RoutePaths.hubWorkerHome,
    UserRole.dropPoint => RoutePaths.dropPointHome,
    UserRole.storekeeper => RoutePaths.storekeeperHome,
  };
}

/// Resolves role from Supabase user metadata.
UserRole roleFromMetadata(Map<String, dynamic>? metadata) {
  final roleValue = metadata?['role'] as String?;
  if (roleValue == null) return UserRole.customer;
  return UserRole.fromValue(roleValue);
}

/// Returns true if the authenticated user may access [location].
bool canAccessRoute(UserRole role, String location) {
  const publicRoutes = {
    RoutePaths.splash,
    RoutePaths.login,
    RoutePaths.register,
  };

  if (publicRoutes.contains(location)) return true;
  if (location == RoutePaths.profile) return true;
  if (location == RoutePaths.notifications) return true;

  // Legacy driver/dispatcher paths still allowed for hub ops roles.
  if (role.isHubOps) {
    if (location.startsWith(RoutePaths.hubWorkerHome)) return true;
    if (location.startsWith(RoutePaths.driverHome)) return true;
    if (location.startsWith(RoutePaths.dispatcherHome)) return true;
  }

  final home = homePathForRole(role);
  return location == home || location.startsWith('$home/');
}
