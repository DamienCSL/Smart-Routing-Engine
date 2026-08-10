import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/sabah_geo.dart';
import '../../../driver/domain/entities/driver_task.dart';
import '../../data/driver_location_service.dart';
import '../../data/osrm_route_service.dart';
import '../../data/sabah_geocoder.dart';

/// Arguments for in-app Leaflet navigation to one consignment stop.
class DriverNavigateArgs {
  const DriverNavigateArgs({
    required this.cnNo,
    required this.type,
    required this.address,
    this.zone,
    this.lat,
    this.lng,
  });

  final String cnNo;
  final DriverTaskType type;
  final String address;
  final String? zone;
  final double? lat;
  final double? lng;

  bool get isPickup => type == DriverTaskType.pickup;

  String get title => isPickup ? 'Route to pickup' : 'Route to delivery';

  factory DriverNavigateArgs.fromTask(DriverTask task) {
    final s = task.shipment;
    final pickup = task.type == DriverTaskType.pickup;
    final parts = pickup
        ? [s.originAddress, s.originCity]
        : [s.destinationAddress, s.destinationCity];
    return DriverNavigateArgs(
      cnNo: s.trackingNumber,
      type: task.type,
      address: parts.where((e) => e.trim().isNotEmpty).join(', '),
      zone: pickup ? s.originZone : s.destinationZone,
      lat: pickup ? s.originLat : s.destinationLat,
      lng: pickup ? s.originLng : s.destinationLng,
    );
  }
}

/// Waze/Grab-style guidance: OSM Leaflet map + OSRM driving polyline.
class DriverNavigateScreen extends StatefulWidget {
  const DriverNavigateScreen({super.key, required this.args});

  final DriverNavigateArgs args;

  @override
  State<DriverNavigateScreen> createState() => _DriverNavigateScreenState();
}

class _DriverNavigateScreenState extends State<DriverNavigateScreen> {
  final _mapController = MapController();
  final _osrm = OsrmRouteService();
  final _geocoder = SabahGeocoder();
  final _gps = DriverLocationService();

  LatLng? _start;
  LatLng? _dest;
  DrivingRoute? _route;
  bool _loading = true;
  String? _error;
  String _startLabel = 'Start';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoute());
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dest = await _resolveDestination();
      final gps = await _gps.currentPosition();
      final start = gps ??
          (widget.args.isPickup
              ? SabahGeo.pickupDepotForZone(widget.args.zone)
              : SabahGeo.deliveryDepotForZone(widget.args.zone));
      final startLabel = gps != null ? 'Your location' : 'Depot';

      final route = await _osrm.route(
        from: start,
        to: dest,
        label: widget.args.cnNo,
      );

      if (!mounted) return;
      setState(() {
        _dest = dest;
        _start = start;
        _startLabel = startLabel;
        _route = route;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<LatLng> _resolveDestination() async {
    final lat = widget.args.lat;
    final lng = widget.args.lng;
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      return LatLng(lat, lng);
    }

    final query = [
      widget.args.address,
      if ((widget.args.zone ?? '').trim().isNotEmpty) widget.args.zone!.trim(),
    ].where((e) => e.trim().isNotEmpty).join(', ');

    if (query.trim().length >= 2) {
      final hits = await _geocoder.search(query);
      if (hits.isNotEmpty) return hits.first.point;
    }

    return SabahGeo.centerForZone(widget.args.zone);
  }

  void _fitRoute() {
    final points = <LatLng>[
      if (_start != null) _start!,
      if (_dest != null) _dest!,
      ...?_route?.points,
    ];
    if (points.length < 2) return;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(36, 36, 36, 220),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final args = widget.args;
    final center = _dest ?? _start ?? SabahGeo.center;

    return Scaffold(
      appBar: AppBar(
        title: Text(args.title),
        actions: [
          IconButton(
            tooltip: 'Recenter route',
            onPressed: _fitRoute,
            icon: const Icon(Icons.zoom_out_map),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
              minZoom: 6.5,
              maxZoom: 18,
              onMapReady: _fitRoute,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.iposb.smartrouting',
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
              if (_route != null && _route!.points.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route!.points,
                      strokeWidth: 12,
                      color: scheme.primary.withValues(alpha: 0.28),
                    ),
                    Polyline(
                      points: _route!.points,
                      strokeWidth: 5.5,
                      color: scheme.secondary,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_start != null)
                    Marker(
                      point: _start!,
                      width: 44,
                      height: 44,
                      child: Tooltip(
                        message: _startLabel,
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: scheme.primary,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.navigation,
                            color: scheme.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  if (_dest != null)
                    Marker(
                      point: _dest!,
                      width: 48,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: Tooltip(
                        message: args.isPickup ? 'Pickup' : 'Delivery',
                        child: Icon(
                          Icons.location_pin,
                          size: 48,
                          color: scheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'CN ${args.cnNo}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      args.address.isEmpty ? 'Destination' : args.address,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    if (_error != null)
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                        ),
                      )
                    else if (_route != null)
                      Row(
                        children: [
                          Icon(Icons.alt_route, color: scheme.secondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$_startLabel → ${args.isPickup ? 'Pickup' : 'Delivery'}'
                              '  ·  ${_route!.distanceLabel}  ·  ${_route!.durationLabel}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (!_loading)
                      Text(
                        'Could not build a driving line. Check the stop coordinates.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Follow the highlighted road line like Waze / Grab. '
                      'Tiles: OpenStreetMap (Leaflet).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
