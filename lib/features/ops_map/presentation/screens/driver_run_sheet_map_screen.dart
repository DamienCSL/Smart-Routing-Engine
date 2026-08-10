import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/sabah_geo.dart';
import '../../data/driver_location_service.dart';
import '../../data/osrm_route_service.dart';
import '../../data/sabah_geocoder.dart';
import '../providers/driver_run_sheet_provider.dart';

/// Multi-stop Leaflet run: first highlighted leg, then next stops in order.
class DriverRunSheetMapScreen extends ConsumerStatefulWidget {
  const DriverRunSheetMapScreen({super.key});

  @override
  ConsumerState<DriverRunSheetMapScreen> createState() =>
      _DriverRunSheetMapScreenState();
}

class _ResolvedStop {
  const _ResolvedStop({required this.stop, required this.point});

  final DriverRouteStop stop;
  final LatLng point;
}

class _DriverRunSheetMapScreenState
    extends ConsumerState<DriverRunSheetMapScreen> {
  final _mapController = MapController();
  final _osrm = OsrmRouteService();
  final _geocoder = SabahGeocoder();
  final _gps = DriverLocationService();

  LatLng? _start;
  String _startLabel = 'Start';
  List<_ResolvedStop> _resolved = const [];
  List<DrivingRoute> _legs = const [];
  bool _loading = false;
  bool _autoOrder = true;
  bool _ignoreSheetListen = false;
  String? _error;
  String? _builtKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuild());
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _rebuild() async {
    final sheet = ref.read(driverRunSheetProvider);
    final key =
        '${_autoOrder ? 'auto' : 'manual'}|${sheet.map((s) => s.id).join(',')}';
    if (key == _builtKey && _legs.isNotEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final gps = await _gps.currentPosition();
      final start = gps ??
          SabahGeo.pickupDepotForZone(sheet.isEmpty ? null : sheet.first.zone);
      final startLabel = gps != null ? 'Your location' : 'Depot';

      final resolved = <_ResolvedStop>[];
      for (final stop in sheet) {
        final point = await _resolvePoint(stop);
        resolved.add(_ResolvedStop(stop: stop.copyWith(
          lat: point.latitude,
          lng: point.longitude,
        ), point: point));
      }

      if (_autoOrder && resolved.length >= 2) {
        const distance = Distance();
        final remaining = [...resolved];
        final ordered = <_ResolvedStop>[];
        var cursor = start;
        while (remaining.isNotEmpty) {
          remaining.sort(
            (a, b) => distance(cursor, a.point).compareTo(
              distance(cursor, b.point),
            ),
          );
          final next = remaining.removeAt(0);
          ordered.add(next);
          cursor = next.point;
        }
        resolved
          ..clear()
          ..addAll(ordered);
        _ignoreSheetListen = true;
        ref.read(driverRunSheetProvider.notifier).replaceAll(
              ordered.map((e) => e.stop).toList(),
            );
        _ignoreSheetListen = false;
      }

      final legs = resolved.isEmpty
          ? const <DrivingRoute>[]
          : await _osrm.chainedRoute(
              start: start,
              stops: [
                for (final s in resolved)
                  (to: s.point, label: 'CN ${s.stop.cnNo}'),
              ],
            );

      if (!mounted) return;
      _builtKey =
          '${_autoOrder ? 'auto' : 'manual'}|${resolved.map((e) => e.stop.id).join(',')}';
      setState(() {
        _start = start;
        _startLabel = startLabel;
        _resolved = resolved;
        _legs = legs;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<LatLng> _resolvePoint(DriverRouteStop stop) async {
    final lat = stop.lat;
    final lng = stop.lng;
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      return LatLng(lat, lng);
    }
    final query = [
      stop.address,
      if ((stop.zone ?? '').trim().isNotEmpty) stop.zone!.trim(),
    ].where((e) => e.trim().isNotEmpty).join(', ');
    if (query.trim().length >= 2) {
      final hits = await _geocoder.search(query);
      if (hits.isNotEmpty) return hits.first.point;
    }
    return SabahGeo.centerForZone(stop.zone);
  }

  void _fit() {
    final points = <LatLng>[
      if (_start != null) _start!,
      for (final s in _resolved) s.point,
      for (final leg in _legs) ...leg.points,
    ];
    if (points.length < 2) return;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(36, 36, 36, 260),
        ),
      );
    } catch (_) {}
  }

  Color _legColor(BuildContext context, int index) {
    final scheme = Theme.of(context).colorScheme;
    if (index == 0) return scheme.secondary;
    if (index == 1) return scheme.primary;
    return scheme.tertiary;
  }

  String _legTitle(int index) {
    if (index == 0) return 'Go first';
    if (index == 1) return 'Go next';
    return 'Then ${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final sheet = ref.watch(driverRunSheetProvider);
    ref.listen(driverRunSheetProvider, (prev, next) {
      if (_ignoreSheetListen) return;
      if (prev?.map((s) => s.id).join() != next.map((s) => s.id).join()) {
        _builtKey = null;
        _rebuild();
      }
    });

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final center = _start ?? SabahGeo.center;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route to pickup'),
        actions: [
          if (sheet.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(driverRunSheetProvider.notifier).clear();
                setState(() {
                  _resolved = const [];
                  _legs = const [];
                  _builtKey = null;
                });
              },
              child: const Text('Clear'),
            ),
          IconButton(
            tooltip: 'Recenter',
            onPressed: _fit,
            icon: const Icon(Icons.zoom_out_map),
          ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Auto order (nearest first)'),
            subtitle: const Text(
              'First stop is closest. Next stops follow the shortest chain.',
            ),
            value: _autoOrder,
            onChanged: (v) {
              setState(() => _autoOrder = v);
              _builtKey = null;
              _rebuild();
            },
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 12,
                    minZoom: 6.5,
                    maxZoom: 18,
                    onMapReady: _fit,
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
                    if (_legs.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          for (var i = 0; i < _legs.length; i++) ...[
                            Polyline(
                              points: _legs[i].points,
                              strokeWidth: i == 0 ? 14 : 10,
                              color: _legColor(context, i).withValues(
                                alpha: 0.25,
                              ),
                            ),
                            Polyline(
                              points: _legs[i].points,
                              strokeWidth: i == 0 ? 6 : 4.5,
                              color: _legColor(context, i),
                            ),
                          ],
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
                        for (var i = 0; i < _resolved.length; i++)
                          Marker(
                            point: _resolved[i].point,
                            width: 36,
                            height: 36,
                            child: _NumberBadge(
                              number: i + 1,
                              color: _legColor(context, i),
                              label: _resolved[i].stop.cnNo,
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
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _StopCard(
                    startLabel: _startLabel,
                    error: _error,
                    empty: sheet.isEmpty,
                    resolved: _resolved,
                    legs: _legs,
                    legTitle: _legTitle,
                    onRemove: (index) {
                      ref.read(driverRunSheetProvider.notifier).removeAt(index);
                    },
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

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({
    required this.number,
    required this.color,
    required this.label,
  });

  final int number;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(blurRadius: 6, color: Color(0x44000000)),
          ],
        ),
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.startLabel,
    required this.error,
    required this.empty,
    required this.resolved,
    required this.legs,
    required this.legTitle,
    required this.onRemove,
  });

  final String startLabel;
  final String? error;
  final bool empty;
  final List<_ResolvedStop> resolved;
  final List<DrivingRoute> legs;
  final String Function(int index) legTitle;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: empty
              ? Text(
                  'Add consignments from the driver dashboard with “Add to route”. '
                  'The map then highlights which stop to do first and which is next.',
                  style: theme.textTheme.bodyMedium,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Run sheet · ${resolved.length} stop${resolved.length == 1 ? '' : 's'}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: resolved.length,
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemBuilder: (context, i) {
                          final stop = resolved[i].stop;
                          final leg = i < legs.length ? legs[i] : null;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: i == 0
                                    ? theme.colorScheme.secondary
                                    : theme.colorScheme.primaryContainer,
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: i == 0
                                        ? theme.colorScheme.onSecondary
                                        : theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${legTitle(i)} · CN ${stop.cnNo} · ${stop.typeLabel}',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      stop.address.isEmpty
                                          ? 'Stop'
                                          : stop.address,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    if (leg != null)
                                      Text(
                                        i == 0
                                            ? '$startLabel → this stop · ${leg.distanceLabel} · ${leg.durationLabel}'
                                            : 'Previous → this stop · ${leg.distanceLabel} · ${leg.durationLabel}',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove from route',
                                onPressed: () => onRemove(i),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Amber line = go first. Follow the numbered Leaflet route like Waze / Grab.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
