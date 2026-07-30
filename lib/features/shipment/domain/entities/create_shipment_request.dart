import 'package:equatable/equatable.dart';

/// Input for creating a new customer shipment.
class CreateShipmentRequest extends Equatable {
  const CreateShipmentRequest({
    required this.originAddress,
    required this.originCity,
    required this.originProvince,
    required this.originZone,
    required this.originLat,
    required this.originLng,
    required this.destinationAddress,
    required this.destinationCity,
    required this.destinationProvince,
    required this.destinationZone,
    required this.destinationLat,
    required this.destinationLng,
    required this.weightKg,
    required this.packageCount,
    this.packageDescription,
  });

  final String originAddress;
  final String originCity;
  final String originProvince;
  final String originZone;
  final double originLat;
  final double originLng;
  final String destinationAddress;
  final String destinationCity;
  final String destinationProvince;
  final String destinationZone;
  final double destinationLat;
  final double destinationLng;
  final String? packageDescription;
  final double weightKg;
  final int packageCount;

  @override
  List<Object?> get props => [
        originAddress,
        originCity,
        originProvince,
        originZone,
        originLat,
        originLng,
        destinationAddress,
        destinationCity,
        destinationProvince,
        destinationZone,
        destinationLat,
        destinationLng,
        packageDescription,
        weightKg,
        packageCount,
      ];
}
