import 'package:latlong2/latlong.dart';

/// A location confirmed on the ops map (search + pin refine).
class PickedLocation {
  const PickedLocation({
    required this.point,
    required this.label,
    required this.zoneCode,
    this.city,
    this.state = 'Sabah',
    this.contactName,
    this.phone,
  });

  final LatLng point;
  final String label;
  final String zoneCode;
  final String? city;
  final String state;
  final String? contactName;
  final String? phone;

  String get shortSummary {
    final cityValue = city?.trim() ?? '';
    final cityPart =
        cityValue.isEmpty ||
            label.toLowerCase().contains(cityValue.toLowerCase())
        ? ''
        : ', $cityValue';
    return '$label$cityPart';
  }
}

/// A geocoder search hit shown in the search results list.
class GeocodeSuggestion {
  const GeocodeSuggestion({
    required this.point,
    required this.label,
    this.city,
    this.state,
  });

  final LatLng point;
  final String label;
  final String? city;
  final String? state;
}
