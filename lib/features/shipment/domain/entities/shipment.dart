import 'package:equatable/equatable.dart';

import '../../../../shared/enums/shipment_status.dart';

/// Domain entity for a logistics shipment.
class Shipment extends Equatable {
  const Shipment({
    required this.id,
    required this.trackingNumber,
    required this.customerId,
    required this.originAddress,
    required this.originCity,
    required this.originProvince,
    required this.originZone,
    required this.destinationAddress,
    required this.destinationCity,
    required this.destinationProvince,
    required this.destinationZone,
    required this.weightKg,
    required this.packageCount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.originLat,
    this.originLng,
    this.destinationLat,
    this.destinationLng,
    this.packageDescription,
    this.eta,
    this.pickupHubWorkerId,
    this.deliveryHubWorkerId,
    this.pickupDispatcherId,
    this.pickupDriverId,
    this.originDropPointId,
    this.originHubId,
    this.storekeeperId,
    this.sortingHubId,
    this.destinationHubId,
    this.destinationDropPointId,
    this.deliveryDispatcherId,
    this.deliveryDriverId,
  });

  final String id;
  final String trackingNumber;
  final String customerId;
  final String originAddress;
  final String originCity;
  final String originProvince;
  final String originZone;
  final double? originLat;
  final double? originLng;
  final String destinationAddress;
  final String destinationCity;
  final String destinationProvince;
  final String destinationZone;
  final double? destinationLat;
  final double? destinationLng;
  final String? packageDescription;
  final double weightKg;
  final int packageCount;
  final ShipmentStatus status;
  final DateTime? eta;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Hub-first assignment
  final String? pickupHubWorkerId;
  final String? deliveryHubWorkerId;

  // Legacy split-role FKs (may be null after 011)
  final String? pickupDispatcherId;
  final String? pickupDriverId;
  final String? originDropPointId;
  final String? originHubId;
  final String? storekeeperId;
  final String? sortingHubId;
  final String? destinationHubId;
  final String? destinationDropPointId;
  final String? deliveryDispatcherId;
  final String? deliveryDriverId;

  String get routeLabel => '$originZone → $destinationZone';

  bool get isAssigned =>
      status != ShipmentStatus.pending && status != ShipmentStatus.failed;

  int get assignedRoleCount {
    return [
      pickupHubWorkerId,
      deliveryHubWorkerId,
      pickupDispatcherId,
      pickupDriverId,
      originDropPointId,
      originHubId,
      storekeeperId,
      sortingHubId,
      destinationHubId,
      destinationDropPointId,
      deliveryDispatcherId,
      deliveryDriverId,
    ].where((id) => id != null).length;
  }

  @override
  List<Object?> get props => [id, trackingNumber, status, updatedAt, eta];
}
