import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../../../ops_map/domain/entities/picked_location.dart';

enum AddressBookKind {
  pickup,
  delivery,
  both;

  static AddressBookKind fromApi(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'pickup':
        return AddressBookKind.pickup;
      case 'delivery':
        return AddressBookKind.delivery;
      default:
        return AddressBookKind.both;
    }
  }

  String get apiValue => name;

  String get label => switch (this) {
        AddressBookKind.pickup => 'Pickup',
        AddressBookKind.delivery => 'Delivery',
        AddressBookKind.both => 'Pickup & delivery',
      };

  bool matchesFilter(AddressBookKind filter) {
    if (this == AddressBookKind.both) return true;
    return this == filter;
  }
}

class SavedAddress extends Equatable {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.kind,
    required this.address,
    this.contactName,
    this.phone,
    this.city,
    this.state = 'Sabah',
    this.zoneCode,
    this.lat,
    this.lng,
    this.isDefault = false,
  });

  final int id;
  final String label;
  final AddressBookKind kind;
  final String address;
  final String? contactName;
  final String? phone;
  final String? city;
  final String state;
  final String? zoneCode;
  final double? lat;
  final double? lng;
  final bool isDefault;

  String get summary {
    final cityPart = (city == null || city!.isEmpty) ? '' : ', $city';
    return '$address$cityPart';
  }

  bool get hasCoordinates => lat != null && lng != null;

  PickedLocation? toPickedLocation() {
    if (!hasCoordinates) return null;
    final zone = (zoneCode == null || zoneCode!.isEmpty)
        ? 'KK-METRO'
        : zoneCode!;
    return PickedLocation(
      point: LatLng(lat!, lng!),
      label: address,
      zoneCode: zone,
      city: city,
      state: state,
      contactName: contactName,
      phone: phone,
    );
  }

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      label: (json['label'] ?? 'Saved').toString(),
      kind: AddressBookKind.fromApi(json['kind']?.toString()),
      address: (json['address'] ?? '').toString(),
      contactName: json['contactName']?.toString(),
      phone: json['phone']?.toString(),
      city: json['city']?.toString(),
      state: (json['state'] ?? 'Sabah').toString(),
      zoneCode: json['zoneCode']?.toString(),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      isDefault: json['isDefault'] == true || json['isDefault'] == 1,
    );
  }

  Map<String, dynamic> toCreateBody() => {
        'label': label,
        'kind': kind.apiValue,
        'address': address,
        if (contactName != null && contactName!.isNotEmpty)
          'contactName': contactName,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (city != null && city!.isNotEmpty) 'city': city,
        'state': state,
        if (zoneCode != null && zoneCode!.isNotEmpty) 'zoneCode': zoneCode,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'isDefault': isDefault,
      };

  @override
  List<Object?> get props => [id, label, address, kind];
}
