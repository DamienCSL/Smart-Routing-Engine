/// Centralized route path definitions for GoRouter.
abstract final class RoutePaths {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String profile = '/profile';
  static const String notifications = '/notifications';

  static const String customerHome = '/customer';
  static const String customerCreateShipment = '/customer/create';
  static const String customerPickLocation = '/customer/pick-location';
  static const String customerShipmentDetailPath = '/customer/shipments/:id';

  static String customerShipmentDetail(String id) => '/customer/shipments/$id';

  static const String driverHome = '/driver';
  static const String driverMap = '/driver/map';
  static String driverTaskDetail(String id) => '/driver/tasks/$id';

  /// Opens the driver ops map, optionally prefilled from a task address.
  static String driverMapWithQuery({String? query, double? lat, double? lng}) {
    final params = <String, String>{};
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    if (lat != null) params['lat'] = lat.toString();
    if (lng != null) params['lng'] = lng.toString();
    if (params.isEmpty) return driverMap;
    return Uri(path: driverMap, queryParameters: params).toString();
  }

  static const String dispatcherHome = '/dispatcher';
  static const String dispatcherMap = '/dispatcher/map';
  static const String dispatcherScan = '/dispatcher/scan';
  static String dispatcherShipmentDetail(String id) =>
      '/dispatcher/shipments/$id';

  static const String hubWorkerHome = '/hub-worker';
  static const String hubWorkerMap = '/hub-worker/map';
  static const String hubWorkerScan = '/hub-worker/scan';
  static const String hubWorkerDemoDesk = '/hub-worker/demo-desk';
  static String hubWorkerTaskDetail(String id) => '/hub-worker/tasks/$id';

  /// Public customer tracking (no login in Driver API mode).
  static const String trackOrder = '/track';

  static String hubWorkerMapWithQuery({
    String? query,
    double? lat,
    double? lng,
  }) {
    final params = <String, String>{};
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    if (lat != null) params['lat'] = lat.toString();
    if (lng != null) params['lng'] = lng.toString();
    if (params.isEmpty) return hubWorkerMap;
    return Uri(path: hubWorkerMap, queryParameters: params).toString();
  }

  static const String dropPointHome = '/drop-point';
  static String dropPointTaskDetail(String id) => '/drop-point/tasks/$id';

  static const String storekeeperHome = '/storekeeper';
  static String storekeeperTaskDetail(String id) => '/storekeeper/tasks/$id';
}
