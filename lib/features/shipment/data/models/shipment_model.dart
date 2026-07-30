import '../../../../shared/enums/shipment_status.dart';
import '../../domain/entities/shipment.dart';
import '../../domain/entities/shipment_history_entry.dart';

class ShipmentModel {
  const ShipmentModel({
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

  factory ShipmentModel.fromJson(Map<String, dynamic> json) {
    return ShipmentModel(
      id: json['id'] as String,
      trackingNumber: json['tracking_number'] as String,
      customerId: json['customer_id'] as String,
      originAddress: json['origin_address'] as String,
      originCity: json['origin_city'] as String,
      originProvince: json['origin_province'] as String,
      originZone: json['origin_zone'] as String,
      originLat: (json['origin_lat'] as num?)?.toDouble(),
      originLng: (json['origin_lng'] as num?)?.toDouble(),
      destinationAddress: json['destination_address'] as String,
      destinationCity: json['destination_city'] as String,
      destinationProvince: json['destination_province'] as String,
      destinationZone: json['destination_zone'] as String,
      destinationLat: (json['destination_lat'] as num?)?.toDouble(),
      destinationLng: (json['destination_lng'] as num?)?.toDouble(),
      packageDescription: json['package_description'] as String?,
      weightKg: (json['weight_kg'] as num).toDouble(),
      packageCount: json['package_count'] as int? ?? 1,
      status: ShipmentStatus.fromValue(json['status'] as String? ?? 'pending'),
      eta: json['eta'] != null ? DateTime.parse(json['eta'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      pickupHubWorkerId: json['pickup_hub_worker_id'] as String?,
      deliveryHubWorkerId: json['delivery_hub_worker_id'] as String?,
      pickupDispatcherId: json['pickup_dispatcher_id'] as String?,
      pickupDriverId: json['pickup_driver_id'] as String?,
      originDropPointId: json['origin_drop_point_id'] as String?,
      originHubId: json['origin_hub_id'] as String?,
      storekeeperId: json['storekeeper_id'] as String?,
      sortingHubId: json['sorting_hub_id'] as String?,
      destinationHubId: json['destination_hub_id'] as String?,
      destinationDropPointId: json['destination_drop_point_id'] as String?,
      deliveryDispatcherId: json['delivery_dispatcher_id'] as String?,
      deliveryDriverId: json['delivery_driver_id'] as String?,
    );
  }

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
  final String? pickupHubWorkerId;
  final String? deliveryHubWorkerId;
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

  Shipment toEntity() {
    return Shipment(
      id: id,
      trackingNumber: trackingNumber,
      customerId: customerId,
      originAddress: originAddress,
      originCity: originCity,
      originProvince: originProvince,
      originZone: originZone,
      originLat: originLat,
      originLng: originLng,
      destinationAddress: destinationAddress,
      destinationCity: destinationCity,
      destinationProvince: destinationProvince,
      destinationZone: destinationZone,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      packageDescription: packageDescription,
      weightKg: weightKg,
      packageCount: packageCount,
      status: status,
      eta: eta,
      createdAt: createdAt,
      updatedAt: updatedAt,
      pickupHubWorkerId: pickupHubWorkerId,
      deliveryHubWorkerId: deliveryHubWorkerId,
      pickupDispatcherId: pickupDispatcherId,
      pickupDriverId: pickupDriverId,
      originDropPointId: originDropPointId,
      originHubId: originHubId,
      storekeeperId: storekeeperId,
      sortingHubId: sortingHubId,
      destinationHubId: destinationHubId,
      destinationDropPointId: destinationDropPointId,
      deliveryDispatcherId: deliveryDispatcherId,
      deliveryDriverId: deliveryDriverId,
    );
  }

  static Map<String, dynamic> toInsertJson({
    required String trackingNumber,
    required String customerId,
    required String originAddress,
    required String originCity,
    required String originProvince,
    required String originZone,
    required double originLat,
    required double originLng,
    required String destinationAddress,
    required String destinationCity,
    required String destinationProvince,
    required String destinationZone,
    required double destinationLat,
    required double destinationLng,
    required double weightKg,
    required int packageCount,
    String? packageDescription,
  }) {
    return {
      'tracking_number': trackingNumber,
      'customer_id': customerId,
      'origin_address': originAddress,
      'origin_city': originCity,
      'origin_province': originProvince,
      'origin_zone': originZone,
      'origin_lat': originLat,
      'origin_lng': originLng,
      'destination_address': destinationAddress,
      'destination_city': destinationCity,
      'destination_province': destinationProvince,
      'destination_zone': destinationZone,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
      'package_description': packageDescription,
      'weight_kg': weightKg,
      'package_count': packageCount,
      'status': ShipmentStatus.pending.value,
    };
  }
}

class ShipmentHistoryModel {
  const ShipmentHistoryModel({
    required this.id,
    required this.shipmentId,
    required this.status,
    required this.description,
    required this.createdAt,
    this.location,
    this.performedBy,
  });

  factory ShipmentHistoryModel.fromJson(Map<String, dynamic> json) {
    return ShipmentHistoryModel(
      id: json['id'] as String,
      shipmentId: json['shipment_id'] as String,
      status: ShipmentStatus.fromValue(json['status'] as String? ?? 'pending'),
      description: json['description'] as String,
      location: json['location'] as String?,
      performedBy: json['performed_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String shipmentId;
  final ShipmentStatus status;
  final String description;
  final String? location;
  final String? performedBy;
  final DateTime createdAt;

  ShipmentHistoryEntry toEntity() {
    return ShipmentHistoryEntry(
      id: id,
      shipmentId: shipmentId,
      status: status,
      description: description,
      location: location,
      performedBy: performedBy,
      createdAt: createdAt,
    );
  }
}
