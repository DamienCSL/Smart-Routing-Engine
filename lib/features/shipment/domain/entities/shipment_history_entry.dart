import 'package:equatable/equatable.dart';

import '../../../../shared/enums/shipment_status.dart';

/// A single status-change event on a shipment timeline.
class ShipmentHistoryEntry extends Equatable {
  const ShipmentHistoryEntry({
    required this.id,
    required this.shipmentId,
    required this.status,
    required this.description,
    required this.createdAt,
    this.location,
    this.performedBy,
  });

  final String id;
  final String shipmentId;
  final ShipmentStatus status;
  final String description;
  final String? location;
  final String? performedBy;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, status, createdAt];
}
