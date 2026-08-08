import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/network/driver_api_providers.dart';
import '../../../../core/utils/provider_refresh.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../shipment/presentation/providers/shipment_providers.dart';
import '../../../shipment/presentation/widgets/assignment_summary_card.dart';
import '../../../shipment/presentation/widgets/shipment_status_chip.dart';
import '../../../shipment/presentation/widgets/shipment_timeline.dart';

class ShipmentDetailScreen extends ConsumerWidget {
  const ShipmentDetailScreen({super.key, required this.shipmentId});

  final String shipmentId;

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      refreshAndWait(ref, shipmentDetailProvider(shipmentId).future),
      refreshAndWait(ref, shipmentHistoryProvider(shipmentId).future),
    ]);
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    String trackingNumber,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel shipment?'),
        content: const Text(
          'You can only cancel before the parcel is picked up. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep shipment'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel shipment'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(driverApiClientProvider)
          .cancelCustomerOrder(trackingNumber);
      ref.invalidate(shipmentDetailProvider(shipmentId));
      ref.invalidate(shipmentHistoryProvider(shipmentId));
      ref.invalidate(customerShipmentsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Shipment cancelled')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not cancel shipment: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipmentAsync = ref.watch(shipmentDetailProvider(shipmentId));
    final historyAsync = ref.watch(shipmentHistoryProvider(shipmentId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipment Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(ref),
          ),
        ],
      ),
      body: shipmentAsync.when(
        loading: () => const AppLoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shipment) {
          if (shipment == null) {
            return const Center(child: Text('Shipment not found'));
          }

          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                shipment.trackingNumber,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy tracking number',
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: shipment.trackingNumber),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Tracking number copied'),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ShipmentStatusChip(status: shipment.status),
                        const SizedBox(height: 16),
                        _InfoRow(label: 'Route', value: shipment.routeLabel),
                        _InfoRow(
                          label: 'From',
                          value:
                              '${shipment.originAddress}, ${shipment.originCity}',
                        ),
                        _InfoRow(
                          label: 'To',
                          value:
                              '${shipment.destinationAddress}, ${shipment.destinationCity}',
                        ),
                        _InfoRow(
                          label: 'Package',
                          value:
                              '${shipment.packageCount} pkg · ${shipment.weightKg} kg'
                              '${shipment.packageDescription != null ? ' · ${shipment.packageDescription}' : ''}',
                        ),
                        _InfoRow(
                          label: 'Created',
                          value: DateFormat.yMMMd().add_jm().format(
                            shipment.createdAt.toLocal(),
                          ),
                        ),
                        if (shipment.eta != null)
                          _InfoRow(
                            label: 'ETA',
                            value: DateFormat.yMMMd().add_jm().format(
                              shipment.eta!.toLocal(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(
                          '${RoutePaths.trackOrder}?cn=${Uri.encodeQueryComponent(shipment.trackingNumber)}',
                        ),
                        icon: const Icon(Icons.travel_explore),
                        label: const Text('Track parcel'),
                      ),
                    ),
                    if (Env.useDriverApi &&
                        !Env.isSupabaseConfigured &&
                        (shipment.status == ShipmentStatus.pending ||
                            shipment.status == ShipmentStatus.assigned ||
                            shipment.status ==
                                ShipmentStatus.pickupScheduled)) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _cancel(context, ref, shipment.trackingNumber),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                AssignmentSummaryCard(shipment: shipment),
                const SizedBox(height: 24),
                Text(
                  'Timeline',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                historyAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: AppLoadingIndicator(),
                  ),
                  error: (e, _) => Text('Failed to load history: $e'),
                  data: (entries) => ShipmentTimeline(entries: entries),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

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
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
