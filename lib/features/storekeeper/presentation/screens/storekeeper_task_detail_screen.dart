import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/loading_indicator.dart';
import '../../../drop_point/domain/entities/drop_point_task.dart';
import '../../../shipment/presentation/providers/shipment_providers.dart';
import '../../../shipment/presentation/widgets/shipment_status_chip.dart';
import '../../../shipment/presentation/widgets/shipment_timeline.dart';
import '../../domain/entities/storekeeper_task.dart';
import '../providers/storekeeper_providers.dart';
import '../viewmodels/storekeeper_action_viewmodel.dart';

class StorekeeperTaskDetailScreen extends ConsumerWidget {
  const StorekeeperTaskDetailScreen({super.key, required this.shipmentId});

  final String shipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(storekeeperTaskDetailProvider(shipmentId));
    final historyAsync = ref.watch(shipmentHistoryProvider(shipmentId));
    final actionState = ref.watch(storekeeperActionViewModelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hub Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(storekeeperTaskDetailProvider(shipmentId));
              ref.invalidate(shipmentHistoryProvider(shipmentId));
            },
          ),
        ],
      ),
      body: taskAsync.when(
        loading: () => const AppLoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (task) {
          if (task == null) {
            return const Center(child: Text('Task not found for this hub'));
          }

          final s = task.shipment;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (actionState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    actionState.errorMessage!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShipmentStatusChip(status: s.status),
                      const SizedBox(height: 12),
                      Text(
                        s.trackingNumber,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${s.originCity} → ${s.destinationCity}'),
                      Text(s.routeLabel),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Actions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (task.availableActions.isEmpty)
                Text(
                  'No actions available for current status.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...task.availableActions.map((action) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FilledButton.icon(
                      onPressed: actionState.isLoading
                          ? null
                          : () => _runAction(context, ref, task, action),
                      icon: Icon(_iconFor(action.iconName)),
                      label: Text(action.label),
                    ),
                  );
                }),
              if (actionState.isLoading) ...[
                const SizedBox(height: 8),
                const Center(child: CircularProgressIndicator()),
              ],
              const SizedBox(height: 24),
              Text(
                'Timeline',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              historyAsync.when(
                loading: () => const AppLoadingIndicator(),
                error: (e, _) => Text('History error: $e'),
                data: (entries) => ShipmentTimeline(entries: entries),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    StorekeeperTask task,
    FacilityStatusAction action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action.label),
        content: Text(
          'Update ${task.trackingNumber} to "${action.status.label}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok =
        await ref.read(storekeeperActionViewModelProvider.notifier).updateStatus(
              shipmentId: task.id,
              newStatus: action.status,
            );

    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated to ${action.status.label}')),
      );
    }
  }

  IconData _iconFor(String name) {
    return switch (name) {
      'sort' => Icons.sort,
      'local_shipping' => Icons.local_shipping_outlined,
      'warehouse' => Icons.warehouse_outlined,
      _ => Icons.play_arrow,
    };
  }
}
