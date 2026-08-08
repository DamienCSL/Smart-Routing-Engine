import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/demo_zones.dart';
import '../../../../core/constants/sabah_geo.dart';
import '../../data/osrm_route_service.dart';
import '../../data/sabah_geocoder.dart';
import '../../domain/entities/picked_location.dart';

/// What the Sabah map is used for.
enum SabahMapPurpose {
  /// Customer: search + pin to set shipment geocode (no route network).
  addressGeocode,

  /// Driver / dispatcher: search + pin with hubs/drop-point route network.
  routeOps,
}

/// Shared Sabah map: search a place, then refine with a pin.
class OpsMapScreen extends StatefulWidget {
  const OpsMapScreen({
    super.key,
    required this.title,
    required this.purpose,
    this.initialZone,
    this.initialQuery,
    this.initialPoint,
    this.drivingRoutes = const [],
    this.routesLoading = false,
    this.routeHint,
    this.startPoint,
    this.stopMarkers = const [],
  });

  final String title;
  final SabahMapPurpose purpose;
  final String? initialZone;
  final String? initialQuery;
  final LatLng? initialPoint;

  /// Road polylines (driver → pickup, dispatcher → destination).
  final List<DrivingRoute> drivingRoutes;
  final bool routesLoading;
  final String? routeHint;
  final LatLng? startPoint;
  final List<({LatLng point, String label})> stopMarkers;

  bool get showRouteNetwork => purpose == SabahMapPurpose.routeOps;

  bool get returnPickedLocation => purpose == SabahMapPurpose.addressGeocode;

  @override
  State<OpsMapScreen> createState() => _OpsMapScreenState();
}

class _OpsMapScreenState extends State<OpsMapScreen> {
  final _geocoder = SabahGeocoder();
  final _mapController = MapController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  Timer? _debounce;
  List<GeocodeSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _resolvingPin = false;
  String? _pinResolveError;
  String? _searchError;
  late LatLng _pin;
  PickedLocation? _picked;
  var _didFitRoutes = false;
  var _resolveGeneration = 0;

  @override
  void initState() {
    super.initState();
    _pin = widget.initialPoint ?? SabahGeo.centerForZone(widget.initialZone);
    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty) {
      _searchController.text = q;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runSearch(q);
        _resolvePin(_pin);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolvePin(_pin));
    }
  }

  @override
  void didUpdateWidget(covariant OpsMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.drivingRoutes.isNotEmpty &&
        widget.drivingRoutes != oldWidget.drivingRoutes) {
      _didFitRoutes = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoutes());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _fitRoutes() {
    if (_didFitRoutes || widget.drivingRoutes.isEmpty) return;
    final points = <LatLng>[
      for (final route in widget.drivingRoutes) ...route.points,
    ];
    if (points.length < 2) return;
    _didFitRoutes = true;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(40, 40, 40, 200),
        ),
      );
    } catch (_) {
      // Map may not be ready yet.
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String value) async {
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _suggestions = const [];
        _searchError = null;
        _searching = false;
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
    });

    try {
      final results = await _geocoder.search(q);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _searching = false;
        if (results.isEmpty) {
          _searchError = 'No Sabah matches. Try another place name.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _suggestions = const [];
        _searchError = 'Search failed. Check your connection and try again.';
      });
    }
  }

  Future<void> _selectSuggestion(GeocodeSuggestion suggestion) async {
    _searchFocus.unfocus();
    _resolveGeneration++;
    final zone = SabahGeo.zoneCodeFor(suggestion.point);
    setState(() {
      _suggestions = const [];
      _searchController.text = suggestion.label;
      _pin = suggestion.point;
      _pinResolveError = null;
      // Preserve the exact OpenStreetMap result selected by the customer.
      _picked = PickedLocation(
        point: suggestion.point,
        label: suggestion.label,
        zoneCode: zone,
        city: suggestion.city,
        state: suggestion.state ?? 'Sabah',
      );
      _resolvingPin = false;
    });
    _mapController.move(suggestion.point, 14);
  }

  Future<void> _resolvePin(LatLng point) async {
    final generation = ++_resolveGeneration;
    final zone = SabahGeo.zoneCodeFor(point);
    setState(() {
      _resolvingPin = true;
      _pinResolveError = null;
      _picked = null;
    });
    try {
      final picked = await _geocoder.reverse(point, zoneCode: zone);
      if (!mounted || generation != _resolveGeneration) return;
      setState(() {
        _picked = picked;
        _searchController.text = picked.label;
        _resolvingPin = false;
      });
    } catch (_) {
      if (!mounted || generation != _resolveGeneration) return;
      setState(() {
        _picked = null;
        _pinResolveError =
            'Could not find an address for this pin. Search and choose a '
            'location, or move the pin and try again.';
        _resolvingPin = false;
      });
    }
  }

  void _onMapTap(TapPosition _, LatLng point) {
    if (!SabahGeo.contains(point)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pin must stay inside Sabah.')),
      );
      return;
    }
    setState(() {
      _pin = point;
      _searchController.clear();
      _suggestions = const [];
    });
    _resolvePin(point);
  }

  void _confirm() {
    final picked = _picked;
    if (picked == null) return;

    if (widget.returnPickedLocation) {
      context.pop(picked);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pinned: ${picked.shortSummary} · ${DemoZones.labelOf(picked.zoneCode)}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zoneCode = _picked?.zoneCode ?? SabahGeo.zoneCodeFor(_pin);
    final routeSummary = widget.drivingRoutes.isEmpty
        ? null
        : widget.drivingRoutes
              .map((r) {
                final name = r.label == null ? '' : '${r.label}: ';
                return '$name${r.distanceLabel} · ${r.durationLabel}';
              })
              .join('\n');

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _runSearch,
                  decoration: InputDecoration(
                    labelText: 'Search location in Sabah',
                    hintText: 'e.g. Likas, Inanam, Sandakan Harbour',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _suggestions = const [];
                                      _searchError = null;
                                    });
                                  },
                                )),
                  ),
                ),
                if (_searchError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _searchError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final s = _suggestions[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined),
                            title: Text(s.label),
                            onTap: () => _selectSuggestion(s),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pin,
                    initialZoom: widget.initialPoint != null
                        ? 14
                        : (widget.purpose == SabahMapPurpose.addressGeocode
                              ? 11
                              : SabahGeo.defaultZoom),
                    minZoom: 6.5,
                    maxZoom: 18,
                    onTap: _onMapTap,
                    onMapReady: _fitRoutes,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.iposb.smartrouting',
                    ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                    if (widget.drivingRoutes.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          for (var i = 0; i < widget.drivingRoutes.length; i++)
                            Polyline(
                              points: widget.drivingRoutes[i].points,
                              strokeWidth: 5,
                              color:
                                  Color.lerp(
                                    theme.colorScheme.primary,
                                    theme.colorScheme.tertiary,
                                    widget.drivingRoutes.length == 1
                                        ? 0
                                        : i / widget.drivingRoutes.length,
                                  ) ??
                                  theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (widget.showRouteNetwork)
                          for (final node in SabahGeo.networkPoints)
                            Marker(
                              point: node.point,
                              width: 36,
                              height: 36,
                              child: Tooltip(
                                message: '${node.name} (${node.code})',
                                child: Icon(
                                  node.kind == SabahNetworkKind.hub
                                      ? Icons.warehouse_outlined
                                      : Icons.storefront_outlined,
                                  color: theme.colorScheme.tertiary,
                                  size: 28,
                                ),
                              ),
                            ),
                        if (widget.startPoint != null)
                          Marker(
                            point: widget.startPoint!,
                            width: 40,
                            height: 40,
                            child: Tooltip(
                              message: 'Start',
                              child: Icon(
                                Icons.trip_origin,
                                color: theme.colorScheme.secondary,
                                size: 32,
                              ),
                            ),
                          ),
                        for (final stop in widget.stopMarkers)
                          Marker(
                            point: stop.point,
                            width: 40,
                            height: 40,
                            alignment: Alignment.topCenter,
                            child: Tooltip(
                              message: stop.label,
                              child: Icon(
                                Icons.flag,
                                color: theme.colorScheme.error,
                                size: 36,
                              ),
                            ),
                          ),
                        Marker(
                          point: _pin,
                          width: 48,
                          height: 48,
                          alignment: Alignment.topCenter,
                          child: Icon(
                            Icons.location_pin,
                            size: 48,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (widget.routesLoading)
                  const Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.routeHint ??
                                (widget.showRouteNetwork
                                    ? 'Blue line = driving route. Hubs/drop points mark the network.'
                                    : 'Search first, then tap the map to move the pin for a more accurate address.'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (routeSummary != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              routeSummary,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (_resolvingPin)
                            const LinearProgressIndicator()
                          else ...[
                            if (_pinResolveError != null) ...[
                              Text(
                                _pinResolveError!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              _picked?.shortSummary ?? 'Resolving address…',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  avatar: const Icon(
                                    Icons.map_outlined,
                                    size: 16,
                                  ),
                                  label: Text(DemoZones.labelOf(zoneCode)),
                                ),
                                Chip(
                                  label: Text(
                                    '${_pin.latitude.toStringAsFixed(5)}, '
                                    '${_pin.longitude.toStringAsFixed(5)}',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _picked == null ? null : _confirm,
                              icon: const Icon(Icons.check),
                              label: Text(
                                widget.returnPickedLocation
                                    ? 'Confirm location'
                                    : 'Use this pin',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
