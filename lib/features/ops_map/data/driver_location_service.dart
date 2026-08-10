import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Best-effort live GPS for driver navigation. Returns null if denied/unavailable.
class DriverLocationService {
  Future<LatLng?> currentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }
}
