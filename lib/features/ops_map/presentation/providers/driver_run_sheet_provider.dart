import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../driver/domain/entities/driver_task.dart';

/// One consignment stop on the driver's planned pickup/delivery run.
class DriverRouteStop {
  const DriverRouteStop({
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

  String get id => '${type.value}:$cnNo';

  bool get isPickup => type == DriverTaskType.pickup;

  String get typeLabel => type.label;

  factory DriverRouteStop.fromTask(DriverTask task) {
    final s = task.shipment;
    final pickup = task.type == DriverTaskType.pickup;
    final parts = pickup
        ? [s.originAddress, s.originCity]
        : [s.destinationAddress, s.destinationCity];
    return DriverRouteStop(
      cnNo: s.trackingNumber,
      type: task.type,
      address: parts.where((e) => e.trim().isNotEmpty).join(', '),
      zone: pickup ? s.originZone : s.destinationZone,
      lat: pickup ? s.originLat : s.destinationLat,
      lng: pickup ? s.originLng : s.destinationLng,
    );
  }

  DriverRouteStop copyWith({double? lat, double? lng}) {
    return DriverRouteStop(
      cnNo: cnNo,
      type: type,
      address: address,
      zone: zone,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }
}

class DriverRunSheetNotifier extends StateNotifier<List<DriverRouteStop>> {
  DriverRunSheetNotifier() : super(const []);

  int indexOfId(String id) => state.indexWhere((s) => s.id == id);

  bool containsTask(DriverTask task) =>
      indexOfId(DriverRouteStop.fromTask(task).id) >= 0;

  void toggleTask(DriverTask task) {
    final stop = DriverRouteStop.fromTask(task);
    final i = indexOfId(stop.id);
    if (i >= 0) {
      state = [...state]..removeAt(i);
      return;
    }
    state = [...state, stop];
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    state = [...state]..removeAt(index);
  }

  void clear() => state = const [];

  void replaceAll(List<DriverRouteStop> stops) => state = List.of(stops);

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final next = [...state];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    state = next;
  }

  /// Nearest-neighbor order from [start] using known coordinates.
  void optimizeFrom(LatLng start) {
    if (state.length < 2) return;
    const distance = Distance();
    final remaining = [...state];
    final ordered = <DriverRouteStop>[];
    var cursor = start;
    while (remaining.isNotEmpty) {
      var bestI = 0;
      var bestM = double.infinity;
      for (var i = 0; i < remaining.length; i++) {
        final p = _pointOf(remaining[i]);
        if (p == null) continue;
        final m = distance(cursor, p);
        if (m < bestM) {
          bestM = m;
          bestI = i;
        }
      }
      final pick = remaining.removeAt(bestI);
      ordered.add(pick);
      cursor = _pointOf(pick) ?? cursor;
    }
    state = ordered;
  }

  static LatLng? _pointOf(DriverRouteStop stop) {
    final lat = stop.lat;
    final lng = stop.lng;
    if (lat == null || lng == null || lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
  }
}

final driverRunSheetProvider =
    StateNotifierProvider<DriverRunSheetNotifier, List<DriverRouteStop>>((ref) {
  return DriverRunSheetNotifier();
});
