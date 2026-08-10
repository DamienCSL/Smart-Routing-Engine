import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shipment/presentation/widgets/shipment_status_chip.dart';
import '../../domain/entities/driver_task.dart';

class DriverTaskTile extends StatelessWidget {
  const DriverTaskTile({
    super.key,
    required this.task,
    required this.onTap,
    this.onRoute,
  });

  final DriverTask task;
  final VoidCallback onTap;
  final VoidCallback? onRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shipment = task.shipment;
    final date =
        DateFormat.yMMMd().add_jm().format(shipment.createdAt.toLocal());

    final address = task.type == DriverTaskType.pickup
        ? shipment.originAddress
        : shipment.destinationAddress;
    final city = task.type == DriverTaskType.pickup
        ? shipment.originCity
        : shipment.destinationCity;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    task.type == DriverTaskType.pickup
                        ? Icons.upload_outlined
                        : Icons.download_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shipment.trackingNumber,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ShipmentStatusChip(status: shipment.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$city · ${task.type.label}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(address, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(
                date,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              if (onRoute != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: onRoute,
                    icon: const Icon(Icons.alt_route, size: 18),
                    label: Text(
                      task.type == DriverTaskType.pickup
                          ? 'Route to pickup'
                          : 'Route to delivery',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
