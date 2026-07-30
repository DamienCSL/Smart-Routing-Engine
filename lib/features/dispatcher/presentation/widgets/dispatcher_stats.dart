import 'package:flutter/material.dart';

import '../../../shipment/domain/entities/shipment.dart';
import '../../../../shared/enums/shipment_status.dart';

class DispatcherStats {
  const DispatcherStats({
    required this.total,
    required this.active,
    required this.pickupQueue,
    required this.inbound,
    required this.delivered,
  });

  factory DispatcherStats.fromShipments(
    List<Shipment> shipments,
    String zone,
  ) {
    var active = 0;
    var pickupQueue = 0;
    var inbound = 0;
    var delivered = 0;

    for (final s in shipments) {
      final status = s.status;

      if (status == ShipmentStatus.delivered) {
        delivered++;
        continue;
      }
      if (status == ShipmentStatus.cancelled || status == ShipmentStatus.failed) {
        continue;
      }

      active++;

      if (s.originZone == zone &&
          const {
            ShipmentStatus.assigned,
            ShipmentStatus.pickupScheduled,
            ShipmentStatus.pickedUp,
          }.contains(status)) {
        pickupQueue++;
      }

      if (s.destinationZone == zone &&
          const {
            ShipmentStatus.inTransit,
            ShipmentStatus.atDestinationHub,
            ShipmentStatus.atDestinationDropPoint,
            ShipmentStatus.outForDelivery,
          }.contains(status)) {
        inbound++;
      }
    }

    return DispatcherStats(
      total: shipments.length,
      active: active,
      pickupQueue: pickupQueue,
      inbound: inbound,
      delivered: delivered,
    );
  }

  final int total;
  final int active;
  final int pickupQueue;
  final int inbound;
  final int delivered;
}

class DispatcherStatCard extends StatelessWidget {
  const DispatcherStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
