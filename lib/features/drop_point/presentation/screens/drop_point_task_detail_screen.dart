import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/loading_indicator.dart';
import '../../../drop_point/domain/entities/drop_point_task.dart';
import '../../../shipment/presentation/providers/shipment_providers.dart';
import '../../../shipment/presentation/widgets/shipment_status_chip.dart';
import '../../../shipment/presentation/widgets/shipment_timeline.dart';
import '../providers/drop_point_providers.dart';
import '../viewmodels/drop_point_action_viewmodel.dart';

class DropPointTaskDetailScreen extends ConsumerWidget {
  const DropPointTaskDetailScreen({super.key, required this.shipmentId});

  final String shipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(dropPointTaskDetailProvider(shipmentId));
    final historyAsync = ref.watch(shipmentHistoryProvider(shipmentId));
    final actionState = ref.watch(dropPointActionViewModelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drop Point Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dropPointTaskDetailProvider(shipmentId));
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
            return const Center(child: Text('Task not found for this drop point'));
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
                      Row(
                        children: [
                          Chip(label: Text(task.queueType.label)),
                          const Spacer(),
                          ShipmentStatusChip(status: s.status),
                        ],
                      ),
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
    DropPointTask task,
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

    final ok = await ref.read(dropPointActionViewModelProvider.notifier).updateStatus(
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
      'warehouse' => Icons.warehouse_outlined,
      'store' => Icons.store_outlined,
      _ => Icons.play_arrow,
    };
  }
}
