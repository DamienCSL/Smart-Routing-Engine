import 'package:flutter/material.dart';

import '../../../../core/config/env.dart';
import '../../domain/entities/shipment.dart';

class AssignmentSummaryCard extends StatelessWidget {
  const AssignmentSummaryCard({super.key, required this.shipment});

  final Shipment shipment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // IPOSB MySQL / dispatch flow — not the Supabase assignment engine.
    if (Env.useDriverApi && !Env.isSupabaseConfigured) {
      return _IposbDispatchCard(shipment: shipment);
    }

    if (!shipment.isAssigned && shipment.assignedRoleCount == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          shipment.status.label == 'Failed'
              ? 'Assignment failed — check that a routing rule exists for this zone pair and hub workers were seeded (011 + demo_staff).'
              : 'Waiting for Assignment Engine…',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final rows = <(String, String?)>[
      ('Pickup Hub Worker', _short(shipment.pickupHubWorkerId)),
      ('Origin Drop Point', _short(shipment.originDropPointId)),
      ('Origin Hub', _short(shipment.originHubId)),
      ('Storekeeper', _short(shipment.storekeeperId)),
      ('Sorting Hub', _short(shipment.sortingHubId)),
      ('Destination Hub', _short(shipment.destinationHubId)),
      ('Destination Drop Point', _short(shipment.destinationDropPointId)),
      ('Delivery Hub Worker', _short(shipment.deliveryHubWorkerId)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assignment Engine Result',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${shipment.assignedRoleCount} nodes assigned via routing rules',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text(
                        row.$1,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2 ?? '— not available —',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: row.$2 == null
                              ? theme.colorScheme.error
                              : null,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _short(String? id) {
    if (id == null) return null;
    if (id.length <= 12) return id;
    return '${id.substring(0, 8)}…';
  }
}

class _IposbDispatchCard extends StatelessWidget {
  const _IposbDispatchCard({required this.shipment});

  final Shipment shipment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final driverId =
        shipment.deliveryDriverId ?? shipment.deliveryHubWorkerId;
    final hasDriver = driverId != null && driverId.isNotEmpty;

    final title =
        hasDriver ? 'Driver assigned' : 'Awaiting dispatcher assignment';
    final body = hasDriver
        ? 'Driver #$driverId will handle pickup / delivery for this CN.'
        : 'Order is in IPOSB as Pending Pickup. A dispatcher assigns a driver '
            'from FMS Driver Assignment or the Demo desk.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasDriver) ...[
              const SizedBox(height: 12),
              Text(
                'Assigned driver id: $driverId',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
