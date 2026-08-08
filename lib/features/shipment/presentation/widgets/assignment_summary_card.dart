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
              ? 'We could not prepare this delivery. Please contact support for help.'
              : 'We are preparing the best route and courier for your parcel.',
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
              'Delivery journey',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your parcel has been prepared for each step of its journey.',
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
                        row.$2 == null ? 'Preparing' : 'Ready',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
    final driverId = shipment.deliveryDriverId ?? shipment.deliveryHubWorkerId;
    final hasDriver = driverId != null && driverId.isNotEmpty;

    final title = hasDriver ? 'Courier assigned' : 'Preparing your pickup';
    final body = hasDriver
        ? 'A courier has been assigned. We will keep you updated as your '
              'parcel moves through each delivery stage.'
        : 'We received your shipment request and are arranging a courier. '
              'You will see the next update here once pickup is scheduled.';

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
          ],
        ),
      ),
    );
  }
}
