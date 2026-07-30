import '../../../../core/constants/iposb_status_map.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../../domain/entities/shipment.dart';

/// Maps PHP `/customer/orders` JSON into app [Shipment] entities.
abstract final class CustomerOrderMapper {
  static Shipment fromApi(Map<String, dynamic> order, {String customerId = ''}) {
    final cn = (order['cnNo'] ?? '').toString();
    final code = (order['lastMobileStatus'] ?? order['status'] ?? 'BDE')
        .toString()
        .toUpperCase();
    final created = DateTime.tryParse((order['createdAt'] ?? '').toString()) ??
        DateTime.now();
    final address = (order['address'] ?? '').toString();
    final dest = (order['destination'] ?? 'BKI').toString();
    final origin = (order['origin'] ?? 'BKI').toString();
    final recipient = (order['recipientName'] ?? dest).toString();
    final assignedDriver = order['assignedDriverId'];
    final assignedDriverId = assignedDriver == null || '$assignedDriver' == 'null'
        ? null
        : '$assignedDriver';

    return Shipment(
      id: cn,
      trackingNumber: cn,
      customerId: customerId,
      originAddress: origin,
      originCity: origin,
      originProvince: 'Sabah',
      originZone: origin,
      destinationAddress: address.isNotEmpty ? address : dest,
      destinationCity: recipient,
      destinationProvince: 'Sabah',
      destinationZone: dest,
      weightKg: (order['weight'] as num?)?.toDouble() ?? 1,
      packageCount: (order['pieces'] as num?)?.toInt() ?? 1,
      packageDescription: recipient,
      status: statusFromCnCode(code),
      createdAt: created,
      updatedAt: created,
      deliveryDriverId: assignedDriverId,
    );
  }

  static ShipmentStatus statusFromCnCode(String code) {
    final upper = code.toUpperCase();
    if (upper == 'CAN') return ShipmentStatus.cancelled;
    if (const {'POD', 'PCC', 'PFP', 'PCB', 'PAE'}.contains(upper)) {
      return ShipmentStatus.delivered;
    }
    if (const {'UND', 'OVN', 'N13', 'N12', 'N9', 'UTL'}.contains(upper)) {
      return ShipmentStatus.failed;
    }
    if (const {'OFD', 'DRS', 'SHB', 'SCF'}.contains(upper)) {
      return ShipmentStatus.outForDelivery;
    }
    if (upper == 'PKU') return ShipmentStatus.pickedUp;
    if (const {'ACC'}.contains(upper)) return ShipmentStatus.assigned;
    if (const {'BDE', ''}.contains(upper)) return ShipmentStatus.pending;
    // Prefer customer label semantics for everything else.
    final label = IposbStatusMap.customerLabelOf(upper);
    return switch (label) {
      'Pending Pickup' => ShipmentStatus.pending,
      'Collected' => ShipmentStatus.pickedUp,
      'To Be Delivered' => ShipmentStatus.outForDelivery,
      'Signed / Delivered' => ShipmentStatus.delivered,
      'Problematic / Delayed' => ShipmentStatus.failed,
      _ => ShipmentStatus.inTransit,
    };
  }

  static String branchFromZone(String zone) {
    final z = zone.toUpperCase();
    if (z.contains('SAND')) return 'SDK';
    if (z.contains('TAWAU')) return 'TWU';
    if (z.contains('INTERIOR') || z.contains('KK') || z.contains('WEST')) {
      return 'BKI';
    }
    if (z.length <= 10 && RegExp(r'^[A-Z0-9]+$').hasMatch(z)) return z;
    return 'BKI';
  }
}
