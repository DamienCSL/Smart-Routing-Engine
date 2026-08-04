import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/shipment_history_entry.dart';
import 'shipment_status_chip.dart';

class ShipmentTimeline extends StatelessWidget {
  const ShipmentTimeline({super.key, required this.entries});

  final List<ShipmentHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text('No history yet.');
    }

    final theme = Theme.of(context);

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == entries.length - 1
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  if (i != entries.length - 1)
                    Container(
                      width: 2,
                      height: 48,
                      color: theme.colorScheme.outlineVariant,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShipmentStatusChip(
                        status: entries[i].status,
                        labelOverride: entries[i].shortLabel,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entries[i].description,
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (entries[i].location != null &&
                          entries[i].location!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          entries[i].location!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        DateFormat.yMMMd()
                            .add_jm()
                            .format(entries[i].createdAt.toLocal()),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
