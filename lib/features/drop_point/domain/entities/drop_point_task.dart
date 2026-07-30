import '../../../../shared/enums/shipment_status.dart';
import '../../../shipment/domain/entities/shipment.dart';

enum DropPointQueueType {
  originIntake('origin_intake', 'Origin Intake'),
  destinationIntake('destination_intake', 'Destination Intake');

  const DropPointQueueType(this.value, this.label);
  final String value;
  final String label;
}

class DropPointTask {
  const DropPointTask({
    required this.shipment,
    required this.queueType,
  });

  final Shipment shipment;
  final DropPointQueueType queueType;

  String get id => shipment.id;
  String get trackingNumber => shipment.trackingNumber;
  ShipmentStatus get status => shipment.status;

  List<FacilityStatusAction> get availableActions {
    if (queueType == DropPointQueueType.originIntake) {
      if (status == ShipmentStatus.atOriginDropPoint) {
        return const [
          FacilityStatusAction(
            status: ShipmentStatus.atOriginHub,
            label: 'Forward to Origin Hub',
            iconName: 'warehouse',
          ),
        ];
      }
      return const [];
    }

    if (status == ShipmentStatus.inTransit ||
        status == ShipmentStatus.atDestinationHub) {
      return const [
        FacilityStatusAction(
          status: ShipmentStatus.atDestinationDropPoint,
          label: 'Receive at Drop Point',
          iconName: 'store',
        ),
      ];
    }
    return const [];
  }
}

class FacilityStatusAction {
  const FacilityStatusAction({
    required this.status,
    required this.label,
    required this.iconName,
  });

  final ShipmentStatus status;
  final String label;
  final String iconName;
}
