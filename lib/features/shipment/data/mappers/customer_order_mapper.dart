import '../../../../core/constants/iposb_status_map.dart';
import '../../../../core/constants/demo_zones.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../../domain/entities/shipment.dart';

/// Maps PHP `/customer/orders` JSON into app [Shipment] entities.
abstract final class CustomerOrderMapper {
  static Shipment fromApi(
    Map<String, dynamic> order, {
    String customerId = '',
  }) {
    final cn = (order['cnNo'] ?? '').toString();
    final code = (order['lastMobileStatus'] ?? order['status'] ?? 'BDE')
        .toString()
        .toUpperCase();
    final created =
        DateTime.tryParse((order['createdAt'] ?? '').toString()) ??
        DateTime.now();
    final address = (order['address'] ?? '').toString();
    final dest = (order['destination'] ?? 'BKI').toString();
    final origin = (order['origin'] ?? 'BKI').toString();
    final originZone = (order['originZone'] ?? origin).toString();
    final destinationZone = (order['destinationZone'] ?? dest).toString();
    final senderAddress = (order['senderAddress'] ?? '').toString();
    final assignedDriver = order['assignedDriverId'];
    final assignedDriverId =
        assignedDriver == null || '$assignedDriver' == 'null'
        ? null
        : '$assignedDriver';

    return Shipment(
      id: cn,
      trackingNumber: cn,
      customerId: customerId,
      originAddress: senderAddress.isNotEmpty ? senderAddress : origin,
      originCity: DemoZones.labelOf(originZone),
      originProvince: 'Sabah',
      originZone: originZone,
      originLat: _toDouble(order['originLat']),
      originLng: _toDouble(order['originLng']),
      destinationAddress: address.isNotEmpty ? address : dest,
      destinationCity: DemoZones.labelOf(destinationZone),
      destinationProvince: 'Sabah',
      destinationZone: destinationZone,
      destinationLat: _toDouble(order['destinationLat']),
      destinationLng: _toDouble(order['destinationLng']),
      weightKg: (order['weight'] as num?)?.toDouble() ?? 1,
      packageCount: (order['pieces'] as num?)?.toInt() ?? 1,
      packageDescription: null,
      status: statusFromCnCode(code),
      createdAt: created,
      updatedAt:
          DateTime.tryParse((order['updatedAt'] ?? '').toString()) ?? created,
      deliveryDriverId: assignedDriverId,
      originDropPointId: order['originDropPointId']?.toString(),
      destinationDropPointId: order['destinationDropPointId']?.toString(),
      originHubId: order['plannedViaHub']?.toString(),
      destinationHubId: order['plannedDestHub']?.toString(),
    );
  }

  static double? _toDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse('$raw');
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
    if (const {
      'OFD',
      'DRS',
      'SHB',
      'SCF',
      'CPA',
      'CPI',
      'SCN',
    }.contains(upper)) {
      return ShipmentStatus.outForDelivery;
    }
    if (upper == 'PKU') return ShipmentStatus.pickedUp;
    if (const {'ACC'}.contains(upper)) return ShipmentStatus.assigned;
    if (const {'BDE', ''}.contains(upper)) return ShipmentStatus.pending;
    // Prefer customer label semantics for everything else.
    final label = IposbStatusMap.customerLabelOf(upper);
    return switch (label) {
      'Pending Pickup' => ShipmentStatus.pending,
      'Courier Assigned' ||
      'Assigned — awaiting pickup' => ShipmentStatus.assigned,
      'Collected' => ShipmentStatus.pickedUp,
      'Out for Delivery' ||
      'To Be Delivered' ||
      'Ready for Self-Collection' ||
      'At Collection Point' ||
      'Self-Collection Notice Sent' ||
      'Preparing for Delivery' => ShipmentStatus.outForDelivery,
      'Delivered' || 'Signed / Delivered' => ShipmentStatus.delivered,
      'Delivery Unsuccessful' ||
      'Delivery Delayed' ||
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
