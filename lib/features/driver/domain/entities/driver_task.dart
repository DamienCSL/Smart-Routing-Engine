import '../../../../shared/enums/shipment_status.dart';
import '../../../shipment/domain/entities/shipment.dart';
import '../../../../core/constants/iposb_status_map.dart';

enum DriverTaskType {
  pickup('pickup', 'Pickup'),
  delivery('delivery', 'Delivery');

  const DriverTaskType(this.value, this.label);
  final String value;
  final String label;
}

/// A shipment task assigned to the signed-in driver.
class DriverTask {
  const DriverTask({
    required this.shipment,
    required this.type,
    this.lastMobileStatus,
    this.nextScans = const [],
  });

  final Shipment shipment;
  final DriverTaskType type;
  final String? lastMobileStatus;
  final List<String> nextScans;

  String get id => shipment.id;
  String get trackingNumber => shipment.trackingNumber;
  ShipmentStatus get status => shipment.status;

  /// Next allowed actions — prefer API nextScans when present (SOP pipeline).
  List<DriverStatusAction> get availableActions {
    if (nextScans.isNotEmpty) {
      return nextScans
          .map(
            (code) => DriverStatusAction(
              status: _shipmentStatusForScan(code),
              label: IposbStatusMap.labelOf(code),
              iconName: _iconForScan(code),
              apiStatus: code,
            ),
          )
          .toList();
    }

    if (type == DriverTaskType.pickup) {
      return switch (shipment.status) {
        ShipmentStatus.assigned || ShipmentStatus.pending => const [
            DriverStatusAction(
              status: ShipmentStatus.pickedUp,
              label: 'Pickup from seller',
              iconName: 'inventory',
              apiStatus: IposbStatusMap.pickedUp,
            ),
          ],
        ShipmentStatus.pickedUp => const [
            DriverStatusAction(
              status: ShipmentStatus.atOriginHub,
              label: 'Hub arrival',
              iconName: 'store',
              apiStatus: IposbStatusMap.arrivedHub,
            ),
          ],
        _ => const [],
      };
    }

    return switch (shipment.status) {
      ShipmentStatus.atOriginHub ||
      ShipmentStatus.sorting ||
      ShipmentStatus.inTransit ||
      ShipmentStatus.atDestinationHub =>
        const [
          DriverStatusAction(
            status: ShipmentStatus.outForDelivery,
            label: 'Out for delivery',
            iconName: 'local_shipping',
            apiStatus: IposbStatusMap.outForDelivery,
          ),
        ],
      ShipmentStatus.outForDelivery => const [
          DriverStatusAction(
            status: ShipmentStatus.delivered,
            label: 'Delivered (POD)',
            iconName: 'check_circle',
            apiStatus: IposbStatusMap.delivered,
          ),
          DriverStatusAction(
            status: ShipmentStatus.failed,
            label: 'Undelivered',
            iconName: 'cancel',
            apiStatus: IposbStatusMap.undelivered,
          ),
        ],
      _ => const [],
    };
  }

  bool get isActive => availableActions.isNotEmpty;

  static ShipmentStatus _shipmentStatusForScan(String code) {
    return switch (code.toUpperCase()) {
      IposbStatusMap.accept => ShipmentStatus.assigned,
      IposbStatusMap.pickedUp => ShipmentStatus.pickedUp,
      IposbStatusMap.arrivedHub || IposbStatusMap.atHub =>
        ShipmentStatus.atOriginHub,
      IposbStatusMap.sorted => ShipmentStatus.sorting,
      IposbStatusMap.storekeeper => ShipmentStatus.atDestinationHub,
      IposbStatusMap.outForDelivery || IposbStatusMap.withCourier =>
        ShipmentStatus.outForDelivery,
      IposbStatusMap.delivered => ShipmentStatus.delivered,
      IposbStatusMap.undelivered => ShipmentStatus.failed,
      _ => ShipmentStatus.assigned,
    };
  }

  static String _iconForScan(String code) {
    return switch (code.toUpperCase()) {
      IposbStatusMap.pickedUp => 'inventory',
      IposbStatusMap.arrivedHub || IposbStatusMap.atHub => 'store',
      IposbStatusMap.sorted || IposbStatusMap.storekeeper => 'inventory',
      IposbStatusMap.outForDelivery || IposbStatusMap.withCourier =>
        'local_shipping',
      IposbStatusMap.delivered => 'check_circle',
      IposbStatusMap.undelivered => 'cancel',
      _ => 'play_arrow',
    };
  }
}

class DriverStatusAction {
  const DriverStatusAction({
    required this.status,
    required this.label,
    required this.iconName,
    this.apiStatus,
  });

  final ShipmentStatus status;
  final String label;
  final String iconName;

  /// SOP scan code posted to Driver API when set.
  final String? apiStatus;
}
