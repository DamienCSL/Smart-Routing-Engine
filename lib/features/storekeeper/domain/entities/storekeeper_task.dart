import '../../../../shared/enums/shipment_status.dart';
import '../../../shipment/domain/entities/shipment.dart';
import '../../../drop_point/domain/entities/drop_point_task.dart';

class StorekeeperTask {
  const StorekeeperTask({required this.shipment});

  final Shipment shipment;

  String get id => shipment.id;
  String get trackingNumber => shipment.trackingNumber;
  ShipmentStatus get status => shipment.status;

  List<FacilityStatusAction> get availableActions {
    return switch (status) {
      ShipmentStatus.atOriginHub => const [
          FacilityStatusAction(
            status: ShipmentStatus.sorting,
            label: 'Start Sorting',
            iconName: 'sort',
          ),
        ],
      ShipmentStatus.sorting => const [
          FacilityStatusAction(
            status: ShipmentStatus.inTransit,
            label: 'Dispatch Outbound',
            iconName: 'local_shipping',
          ),
        ],
      ShipmentStatus.inTransit => const [
          FacilityStatusAction(
            status: ShipmentStatus.atDestinationHub,
            label: 'Mark Arrived at Dest Hub',
            iconName: 'warehouse',
          ),
        ],
      _ => const [],
    };
  }

  bool get isActive => availableActions.isNotEmpty;
}
