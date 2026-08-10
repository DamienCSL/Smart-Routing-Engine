import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../constants/route_paths.dart';
import '../network/driver_api_session.dart';
import '../network/supabase_client.dart';
import '../utils/logger.dart';
import 'go_router_refresh.dart';
import 'role_redirect.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/customer/presentation/screens/create_shipment_screen.dart';
import '../../features/customer/presentation/screens/customer_home_screen.dart';
import '../../features/customer/presentation/screens/address_book_screen.dart';
import '../../features/customer/presentation/screens/shipment_detail_screen.dart';
import '../../features/loyalty/presentation/screens/loyalty_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../../features/dispatcher/presentation/screens/dispatcher_home_screen.dart';
import '../../features/drop_point/presentation/screens/drop_point_home_screen.dart';
import '../../features/drop_point/presentation/screens/drop_point_task_detail_screen.dart';
import '../../features/hub_worker/presentation/screens/demo_ops_desk_screen.dart';
import '../../features/driver/domain/entities/driver_task.dart';
import '../../features/hub_worker/presentation/screens/hub_worker_home_screen.dart';
import '../../features/hub_worker/presentation/screens/hub_worker_scan_screen.dart';
import '../../features/hub_worker/presentation/screens/hub_worker_task_detail_screen.dart';
import '../../features/tracking/presentation/screens/track_order_screen.dart';
import '../../features/notification/presentation/screens/notifications_screen.dart';
import '../../features/ops_map/presentation/screens/driver_navigate_screen.dart';
import '../../features/ops_map/presentation/screens/driver_run_sheet_map_screen.dart';
import '../../features/ops_map/presentation/screens/role_ops_map_screens.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/storekeeper/presentation/screens/storekeeper_home_screen.dart';
import '../../features/storekeeper/presentation/screens/storekeeper_task_detail_screen.dart';

List<RouteBase> _sharedAuthRoutes() => [
  GoRoute(
    path: RoutePaths.splash,
    name: 'splash',
    builder: (context, state) => const SplashScreen(),
  ),
  GoRoute(
    path: RoutePaths.login,
    name: 'login',
    builder: (context, state) => const LoginScreen(),
  ),
  GoRoute(
    path: RoutePaths.register,
    name: 'register',
    builder: (context, state) => const RegisterScreen(),
  ),
  GoRoute(
    path: RoutePaths.profile,
    name: 'profile',
    builder: (context, state) => const ProfileScreen(),
  ),
  GoRoute(
    path: RoutePaths.notifications,
    name: 'notifications',
    builder: (context, state) => const NotificationsScreen(),
  ),
];

List<RouteBase> _customerChildRoutes() => [
      GoRoute(
        path: 'create',
        name: 'customerCreate',
        builder: (context, state) => const CreateShipmentScreen(),
      ),
      GoRoute(
        path: 'pick-location',
        name: 'customerPickLocation',
        builder: (context, state) {
          final extra = state.extra;
          final args = extra is AddressPickArgs
              ? extra
              : const AddressPickArgs(title: 'Pick location');
          return CustomerAddressPickerScreen(args: args);
        },
      ),
      GoRoute(
        path: 'addresses',
        name: 'customerAddressBook',
        builder: (context, state) => const AddressBookScreen(),
      ),
      GoRoute(
        path: 'wallet',
        name: 'customerWallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: 'loyalty',
        name: 'customerLoyalty',
        builder: (context, state) => const LoyaltyScreen(),
      ),
      GoRoute(
        path: 'shipments/:id',
        name: 'customerShipmentDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ShipmentDetailScreen(shipmentId: id);
        },
      ),
    ];

List<RouteBase> _hubWorkerRoutes() => [
  GoRoute(
    path: RoutePaths.hubWorkerHome,
    name: 'hubWorker',
    builder: (context, state) => const HubWorkerHomeScreen(),
    routes: [
      GoRoute(
        path: 'demo-desk',
        name: 'hubWorkerDemoDesk',
        builder: (context, state) => const DemoOpsDeskScreen(),
      ),
      GoRoute(
        path: 'scan',
        name: 'hubWorkerScan',
        builder: (context, state) => const HubWorkerScanScreen(),
      ),
      GoRoute(
        path: 'map',
        name: 'hubWorkerMap',
        builder: (context, state) => const DriverRunSheetMapScreen(),
      ),
      GoRoute(
        path: 'navigate',
        name: 'hubWorkerNavigate',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is DriverNavigateArgs) {
            return DriverNavigateScreen(args: extra);
          }
          final q = state.uri.queryParameters;
          final type = q['mode'] == 'delivery'
              ? DriverTaskType.delivery
              : DriverTaskType.pickup;
          return DriverNavigateScreen(
            args: DriverNavigateArgs(
              cnNo: q['cn'] ?? '',
              type: type,
              address: q['q'] ?? '',
              zone: q['zone'],
              lat: double.tryParse(q['lat'] ?? ''),
              lng: double.tryParse(q['lng'] ?? ''),
            ),
          );
        },
      ),
      GoRoute(
        path: 'tasks/:id',
        name: 'hubWorkerTaskDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return HubWorkerTaskDetailScreen(shipmentId: id);
        },
      ),
    ],
  ),
];

final routerProvider = Provider<GoRouter>((ref) {
  if (!Env.isConfigured) {
    AppLogger.info('Router: no backend configured — splash only');
    return GoRouter(
      initialLocation: RoutePaths.splash,
      routes: [
        GoRoute(
          path: RoutePaths.splash,
          builder: (context, state) => const SplashScreen(),
        ),
      ],
    );
  }

  // Driver API only (IPOSB MySQL master) — no Supabase session.
  if (Env.useDriverApi && !Env.isSupabaseConfigured) {
    final sessionListenable = ref.watch(driverApiSessionListenableProvider);
    return GoRouter(
      overridePlatformDefaultLocation: true,
      initialLocation: RoutePaths.login,
      debugLogDiagnostics: true,
      refreshListenable: sessionListenable,
      redirect: (context, state) {
        final location = state.uri.path.isEmpty ? '/' : state.uri.path;
        final session = ref.read(driverApiSessionProvider);
        final isAuthRoute =
            location == RoutePaths.login || location == RoutePaths.register;
        final isSplash = location == RoutePaths.splash || location == '/';
        final isTrack = location == RoutePaths.trackOrder;

        // Customer can track without signing in.
        if (isTrack) return null;

        if (session == null) {
          if (isAuthRoute) return null;
          return RoutePaths.login;
        }
        final home = homePathForRole(session.role);

        // Landing routes after login should follow the role.
        if (isAuthRoute || isSplash) return home;

        final inHomeArea = location == home || location.startsWith('$home/');
        if (!inHomeArea &&
            location != RoutePaths.profile &&
            location != RoutePaths.notifications &&
            !isTrack) {
          return home;
        }
        return null;
      },
      routes: [
        ..._sharedAuthRoutes(),
        GoRoute(
          path: RoutePaths.customerHome,
          name: 'customer',
          builder: (context, state) => const CustomerHomeScreen(),
          routes: _customerChildRoutes(),
        ),
        GoRoute(
          path: RoutePaths.trackOrder,
          name: 'trackOrder',
          builder: (context, state) {
            final cn = state.uri.queryParameters['cn'];
            return TrackOrderScreen(initialCn: cn);
          },
        ),
        GoRoute(
          path: RoutePaths.dispatcherHome,
          name: 'dispatcher',
          builder: (context, state) => const DispatcherHomeScreen(),
          routes: [
            GoRoute(
              path: 'scan',
              name: 'dispatcherScan',
              builder: (context, state) => const HubWorkerScanScreen(),
            ),
          ],
        ),
        ..._hubWorkerRoutes(),
      ],
    );
  }

  final supabase = ref.watch(supabaseClientProvider);

  return GoRouter(
    overridePlatformDefaultLocation: true,
    initialLocation: RoutePaths.login,
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),
    redirect: (context, state) => _redirect(supabase, state),
    routes: [
      ..._sharedAuthRoutes(),
      GoRoute(
        path: RoutePaths.customerHome,
        name: 'customerSupabase',
        builder: (context, state) => const CustomerHomeScreen(),
        routes: [
          GoRoute(
            path: 'create',
            name: 'customerCreateSb',
            builder: (context, state) => const CreateShipmentScreen(),
          ),
          GoRoute(
            path: 'pick-location',
            name: 'customerPickLocationSb',
            builder: (context, state) {
              final extra = state.extra;
              final args = extra is AddressPickArgs
                  ? extra
                  : const AddressPickArgs(title: 'Pick location');
              return CustomerAddressPickerScreen(args: args);
            },
          ),
          GoRoute(
            path: 'addresses',
            name: 'customerAddressBookSb',
            builder: (context, state) => const AddressBookScreen(),
          ),
          GoRoute(
            path: 'wallet',
            name: 'customerWalletSb',
            builder: (context, state) => const WalletScreen(),
          ),
          GoRoute(
            path: 'loyalty',
            name: 'customerLoyaltySb',
            builder: (context, state) => const LoyaltyScreen(),
          ),
          GoRoute(
            path: 'shipments/:id',
            name: 'customerShipmentDetailSb',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ShipmentDetailScreen(shipmentId: id);
            },
          ),
        ],
      ),
      ..._hubWorkerRoutes(),
      GoRoute(
        path: RoutePaths.driverHome,
        name: 'driver',
        redirect: (context, state) {
          final rest = state.uri.path.replaceFirst(RoutePaths.driverHome, '');
          if (rest.isEmpty || rest == '/') return RoutePaths.hubWorkerHome;
          return '${RoutePaths.hubWorkerHome}$rest';
        },
        builder: (context, state) => const HubWorkerHomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.dispatcherHome,
        name: 'dispatcher',
        builder: (context, state) => const DispatcherHomeScreen(),
        routes: [
          GoRoute(
            path: 'map',
            name: 'dispatcherMap',
            builder: (context, state) => const HubWorkerOpsMapScreen(),
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.dropPointHome,
        name: 'dropPoint',
        builder: (context, state) => const DropPointHomeScreen(),
        routes: [
          GoRoute(
            path: 'tasks/:id',
            name: 'dropPointTaskDetail',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return DropPointTaskDetailScreen(shipmentId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.storekeeperHome,
        name: 'storekeeper',
        builder: (context, state) => const StorekeeperHomeScreen(),
        routes: [
          GoRoute(
            path: 'tasks/:id',
            name: 'storekeeperTaskDetail',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return StorekeeperTaskDetailScreen(shipmentId: id);
            },
          ),
        ],
      ),
    ],
  );
});

String? _redirect(SupabaseClient supabase, GoRouterState state) {
  try {
    final location = state.uri.path.isEmpty ? '/' : state.uri.path;
    final session = supabase.auth.currentSession;

    if (!Env.isConfigured) {
      return location == RoutePaths.splash ? null : RoutePaths.splash;
    }

    final isAuthRoute =
        location == RoutePaths.login || location == RoutePaths.register;
    final isSplash = location == RoutePaths.splash || location == '/';

    if (session == null) {
      if (isAuthRoute) return null;
      AppLogger.info('Router: no session at $location → /login');
      return RoutePaths.login;
    }

    final role = roleFromMetadata(session.user.userMetadata);
    final home = homePathForRole(role);

    if (isAuthRoute || isSplash) {
      AppLogger.info('Router: session found → $home');
      return home;
    }

    if (!canAccessRoute(role, location)) return home;

    return null;
  } catch (e, st) {
    AppLogger.error('Router redirect failed', e, st);
    return RoutePaths.login;
  }
}
