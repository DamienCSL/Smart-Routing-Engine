import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/sabah_geo.dart';
import '../../../dispatcher/presentation/providers/dispatcher_providers.dart';
import '../../../driver/domain/entities/driver_task.dart';
import '../../../hub_worker/presentation/providers/hub_worker_providers.dart';
import '../../../shipment/domain/entities/shipment.dart';
import '../../data/osrm_route_service.dart';
import '../../domain/entities/picked_location.dart';
import 'ops_map_screen.dart';

/// Args for the customer address geocode picker (`/customer/pick-location`).
class AddressPickArgs {
  const AddressPickArgs({
    required this.title,
    this.initialZone,
    this.initialQuery,
    this.initialLat,
    this.initialLng,
  });

  final String title;
  final String? initialZone;
  final String? initialQuery;
  final double? initialLat;
  final double? initialLng;
}

/// Customer-only: search + pin to fill shipment geocode (no route network).
class CustomerAddressPickerScreen extends StatelessWidget {
  const CustomerAddressPickerScreen({super.key, required this.args});

  final AddressPickArgs args;

  @override
  Widget build(BuildContext context) {
    LatLng? point;
    if (args.initialLat != null && args.initialLng != null) {
      point = LatLng(args.initialLat!, args.initialLng!);
    }

    return OpsMapScreen(
      title: args.title,
      purpose: SabahMapPurpose.addressGeocode,
      initialZone: args.initialZone,
      initialQuery: args.initialQuery,
      initialPoint: point,
    );
  }
}

/// Dispatcher: road lines from zone hub → each shipment destination.
class DispatcherOpsMapScreen extends ConsumerStatefulWidget {
  const DispatcherOpsMapScreen({super.key});

  @override
  ConsumerState<DispatcherOpsMapScreen> createState() =>
      _DispatcherOpsMapScreenState();
}

class _DispatcherOpsMapScreenState extends ConsumerState<DispatcherOpsMapScreen> {
  final _router = OsrmRouteService();
  List<DrivingRoute> _routes = const [];
  List<({LatLng point, String label})> _stops = const [];
  LatLng? _start;
  bool _loading = false;
  String? _loadedKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromProviders());
  }

  void _syncFromProviders() {
    final zone = ref.read(dispatcherProfileProvider).valueOrNull?.zone;
    final shipments = ref.read(zoneShipmentsProvider).valueOrNull ?? const [];
    _loadDestinations(zone, shipments);
  }

  @override
  Widget build(BuildContext context) {
    final zone = ref.watch(dispatcherProfileProvider).valueOrNull?.zone;

    ref.listen(zoneShipmentsProvider, (_, next) {
      next.whenData((shipments) => _loadDestinations(zone, shipments));
    });
    ref.listen(dispatcherProfileProvider, (_, next) {
      final shipments = ref.read(zoneShipmentsProvider).valueOrNull ?? const [];
      _loadDestinations(next.valueOrNull?.zone, shipments);
    });

    return OpsMapScreen(
      title: 'Zone Route Map',
      purpose: SabahMapPurpose.routeOps,
      initialZone: zone,
      initialPoint: _stops.isNotEmpty ? _stops.first.point : null,
      drivingRoutes: _routes,
      routesLoading: _loading,
      startPoint: _start,
      stopMarkers: _stops,
      routeHint: _stops.isEmpty
          ? 'No destination pins yet. Shipments need a customer map pin on delivery.'
          : 'Lines show driving routes from your zone hub to each delivery destination.',
    );
  }

  Future<void> _loadDestinations(String? zone, List<Shipment> shipments) async {
    final targets = <({LatLng to, String? label})>[];
    for (final s in shipments) {
      final lat = s.destinationLat;
      final lng = s.destinationLng;
      if (lat == null || lng == null) continue;
      targets.add((to: LatLng(lat, lng), label: s.trackingNumber));
    }

    final key =
        '${zone ?? ''}|${targets.map((t) => '${t.to.latitude},${t.to.longitude}').join(';')}';
    if (key == _loadedKey) return;
    _loadedKey = key;

    final from = SabahGeo.deliveryDepotForZone(zone);
    setState(() {
      _loading = true;
      _start = from;
      _stops = [
        for (final t in targets) (point: t.to, label: t.label ?? 'Stop'),
      ];
    });

    if (targets.isEmpty) {
      if (!mounted) return;
      setState(() {
        _routes = const [];
        _loading = false;
      });
      return;
    }

    final routes = await _router.routesForTargets(from: from, targets: targets);
    if (!mounted) return;
    setState(() {
      _routes = routes;
      _loading = false;
    });
  }
}

/// Hub worker / driver: road lines from depot → pickup stop(s).
class DriverOpsMapScreen extends ConsumerStatefulWidget {
  const DriverOpsMapScreen({
    super.key,
    this.initialQuery,
    this.initialLat,
    this.initialLng,
  });

  final String? initialQuery;
  final double? initialLat;
  final double? initialLng;

  @override
  ConsumerState<DriverOpsMapScreen> createState() => _DriverOpsMapScreenState();
}

/// Alias used by hub-worker routes.
typedef HubWorkerOpsMapScreen = DriverOpsMapScreen;

class _DriverOpsMapScreenState extends ConsumerState<DriverOpsMapScreen> {
  final _router = OsrmRouteService();
  List<DrivingRoute> _routes = const [];
  List<({LatLng point, String label})> _stops = const [];
  LatLng? _start;
  bool _loading = false;
  String? _loadedKey;

  LatLng? get _focus {
    if (widget.initialLat != null && widget.initialLng != null) {
      return LatLng(widget.initialLat!, widget.initialLng!);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tasks = ref.read(hubPickupTasksProvider).valueOrNull ?? const [];
      _loadPickups(tasks);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(hubPickupTasksProvider, (_, next) {
      next.whenData(_loadPickups);
    });

    return OpsMapScreen(
      title: 'Route to Pickup',
      purpose: SabahMapPurpose.routeOps,
      initialQuery: widget.initialQuery,
      initialPoint: _focus ?? (_stops.isNotEmpty ? _stops.first.point : null),
      drivingRoutes: _routes,
      routesLoading: _loading,
      startPoint: _start,
      stopMarkers: _stops,
      routeHint: _stops.isEmpty
          ? 'No pickup pins yet. Open a pickup task → Navigate in Google Maps, or create a geocoded shipment.'
          : 'Line shows the driving route from depot to pickup.',
    );
  }

  Future<void> _loadPickups(List<DriverTask> tasks) async {
    final targets = <({LatLng to, String? label})>[];
    final focus = _focus;

    if (focus != null) {
      targets.add((to: focus, label: widget.initialQuery ?? 'Pickup'));
    } else {
      for (final task in tasks) {
        final s = task.shipment;
        final lat = s.originLat;
        final lng = s.originLng;
        if (lat == null || lng == null) continue;
        targets.add((to: LatLng(lat, lng), label: s.trackingNumber));
      }
    }

    final key =
        '${focus?.latitude},${focus?.longitude}|${targets.map((t) => '${t.to.latitude},${t.to.longitude}').join(';')}';
    if (key == _loadedKey) return;
    _loadedKey = key;

    final first = targets.isEmpty ? null : targets.first.to;
    final from = first == null
        ? SabahGeo.pickupDepotForZone(null)
        : SabahGeo.pickupDepotForZone(SabahGeo.zoneCodeFor(first));

    setState(() {
      _loading = true;
      _start = from;
      _stops = [
        for (final t in targets) (point: t.to, label: t.label ?? 'Pickup'),
      ];
    });

    if (targets.isEmpty) {
      if (!mounted) return;
      setState(() {
        _routes = const [];
        _loading = false;
      });
      return;
    }

    final routes = await _router.routesForTargets(from: from, targets: targets);
    if (!mounted) return;
    setState(() {
      _routes = routes;
      _loading = false;
    });
  }
}

/// Re-export for callers that pop a [PickedLocation].
typedef CustomerPickedLocation = PickedLocation;
