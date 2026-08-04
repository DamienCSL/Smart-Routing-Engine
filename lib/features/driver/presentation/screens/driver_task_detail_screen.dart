import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/google_maps_launcher.dart';
import '../../../../core/utils/provider_refresh.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../shipment/presentation/providers/shipment_providers.dart';
import '../../../shipment/presentation/widgets/shipment_status_chip.dart';
import '../../../shipment/presentation/widgets/shipment_timeline.dart';
import '../../domain/entities/driver_task.dart';
import '../providers/driver_providers.dart';
import '../viewmodels/driver_action_viewmodel.dart';

class DriverTaskDetailScreen extends ConsumerWidget {
  const DriverTaskDetailScreen({super.key, required this.shipmentId});

  final String shipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(driverTaskDetailProvider(shipmentId));
    final historyAsync = ref.watch(shipmentHistoryProvider(shipmentId));
    final actionState = ref.watch(driverActionViewModelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await Future.wait([
                refreshAndWait(ref, driverTaskDetailProvider(shipmentId).future),
                refreshAndWait(ref, shipmentHistoryProvider(shipmentId).future),
              ]);
            },
          ),
        ],
      ),
      body: taskAsync.when(
        loading: () => const AppLoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (task) {
          if (task == null) {
            return const Center(
              child: Text('Task not found or not assigned to you'),
            );
          }

          final shipment = task.shipment;
          final address = task.type == DriverTaskType.pickup
              ? '${shipment.originAddress}, ${shipment.originCity}'
              : '${shipment.destinationAddress}, ${shipment.destinationCity}';

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
                          Chip(
                            avatar: Icon(
                              task.type == DriverTaskType.pickup
                                  ? Icons.upload_outlined
                                  : Icons.download_outlined,
                              size: 16,
                            ),
                            label: Text(task.type.label),
                          ),
                          const Spacer(),
                          ShipmentStatusChip(status: shipment.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        shipment.trackingNumber,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Row(label: 'Address', value: address),
                      _Row(
                        label: 'Route',
                        value: shipment.routeLabel,
                      ),
                      _Row(
                        label: 'Package',
                        value:
                            '${shipment.packageCount} pkg · ${shipment.weightKg} kg',
                      ),
                      if (shipment.eta != null)
                        _Row(
                          label: 'ETA',
                          value: DateFormat.yMMMd()
                              .add_jm()
                              .format(shipment.eta!.toLocal()),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final isPickup = task.type == DriverTaskType.pickup;
                          final lat = isPickup
                              ? shipment.originLat
                              : shipment.destinationLat;
                          final lng = isPickup
                              ? shipment.originLng
                              : shipment.destinationLng;
                          final opened = await GoogleMapsLauncher.openDirections(
                            lat: lat,
                            lng: lng,
                            address: address,
                          );
                          if (!context.mounted) return;
                          if (!opened) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not open Google Maps. Check the stop address.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.directions),
                        label: const Text('Navigate in Google Maps'),
                      ),
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
                  'No actions available for the current status.',
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
    DriverTask task,
    DriverStatusAction action,
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

    final ok = await ref.read(driverActionViewModelProvider.notifier).updateStatus(
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
      'schedule' => Icons.schedule,
      'inventory' => Icons.inventory_2_outlined,
      'store' => Icons.store_outlined,
      'local_shipping' => Icons.local_shipping_outlined,
      'check_circle' => Icons.check_circle_outline,
      _ => Icons.play_arrow,
    };
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
