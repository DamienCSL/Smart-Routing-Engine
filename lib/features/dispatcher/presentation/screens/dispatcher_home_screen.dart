import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/demo_zones.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/utils/provider_refresh.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notification/presentation/widgets/notification_bell_button.dart';
import '../../../shipment/presentation/widgets/shipment_list_tile.dart';
import '../providers/dispatcher_providers.dart';
import '../widgets/assign_job_sheet.dart';
import '../widgets/dispatcher_stats.dart';
import '../../domain/entities/zone_driver_summary.dart';

class DispatcherHomeScreen extends ConsumerWidget {
  const DispatcherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final dispatcherAsync = ref.watch(dispatcherProfileProvider);
    final shipmentsAsync = ref.watch(zoneShipmentsProvider);
    final driversAsync = ref.watch(zoneDriversProvider);
    final theme = Theme.of(context);
    final apiMode = Env.useDriverApi && !Env.isSupabaseConfigured;

    return Scaffold(
      appBar: AppBar(
        title: Text(apiMode ? 'Dispatch Desk' : 'Zone Dashboard'),
        actions: [
          if (!apiMode)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: 'Zone route map',
              onPressed: () => context.push(RoutePaths.dispatcherMap),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await Future.wait([
                refreshAndWait(ref, zoneShipmentsProvider.future),
                refreshAndWait(ref, zoneDriversProvider.future),
                refreshAndWait(ref, dispatcherProfileProvider.future),
              ]);
            },
          ),
          if (!apiMode) const NotificationBellButton(),
          IconButton(
            icon: const Icon(Icons.person_outlined),
            onPressed: () => context.push(RoutePaths.profile),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const AppLoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          return dispatcherAsync.when(
            loading: () => const AppLoadingIndicator(),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (dispatcher) {
              if (dispatcher == null) {
                return Center(
                  child: Text(
                    apiMode
                        ? 'Dispatcher profile not linked. '
                            'Use dispatcher@iposb.demo or run sql/007_dispatcher_mobile.sql'
                        : 'Dispatcher profile not found',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    refreshAndWait(ref, zoneShipmentsProvider.future),
                    refreshAndWait(ref, zoneDriversProvider.future),
                  ]);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Hello, ${profile?.fullName ?? 'Dispatcher'}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      apiMode
                          ? 'Branch ${dispatcher.hubId ?? '—'} · '
                              '${DemoZones.labelOf(dispatcher.zone)}\n'
                              'Pull down to refresh · auto-updates every ~12s'
                          : 'Zone: ${DemoZones.labelOf(dispatcher.zone)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    shipmentsAsync.when(
                      loading: () => const SizedBox(
                        height: 80,
                        child: AppLoadingIndicator(),
                      ),
                      error: (e, _) => Text(
                        apiMode
                            ? '$e'
                            : '$e\n\nRun 007_dispatcher_ops.sql in Supabase.',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      data: (shipments) {
                        final stats = DispatcherStats.fromShipments(
                          shipments,
                          dispatcher.zone,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                DispatcherStatCard(
                                  label: apiMode ? 'Unassigned' : 'Total',
                                  value: stats.total,
                                  icon: Icons.inventory_2_outlined,
                                ),
                                const SizedBox(width: 8),
                                DispatcherStatCard(
                                  label: 'Active',
                                  value: stats.active,
                                  icon: Icons.local_shipping_outlined,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                DispatcherStatCard(
                                  label: 'Pickup queue',
                                  value: stats.pickupQueue,
                                  icon: Icons.upload_outlined,
                                ),
                                const SizedBox(width: 8),
                                DispatcherStatCard(
                                  label: 'Inbound',
                                  value: stats.inbound,
                                  icon: Icons.download_outlined,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Drivers (zone-ranked)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            driversAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (_, __) =>
                                  const Text('Could not load drivers'),
                              data: (drivers) => _DriverChips(drivers: drivers),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              apiMode
                                  ? 'Unassigned jobs — tap to assign'
                                  : 'Zone shipments',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (shipments.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 32),
                                child: Text(
                                  apiMode
                                      ? 'No unassigned consignments. '
                                          'Create an order as customer@iposb.demo.'
                                      : 'No shipments in this zone yet. '
                                          'Create one as a customer '
                                          '(Kota Kinabalu Metro → Sandakan).',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            else
                              ...shipments.map(
                                (shipment) => ShipmentListTile(
                                  shipment: shipment,
                                  onTap: () async {
                                    if (!apiMode) {
                                      context.push(
                                        RoutePaths.dispatcherShipmentDetail(
                                          shipment.id,
                                        ),
                                      );
                                      return;
                                    }
                                    final ok = await showAssignJobSheet(
                                      context,
                                      shipment: shipment,
                                    );
                                    if (ok == true && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Assigned ${shipment.trackingNumber}',
                                          ),
                                        ),
                                      );
                                      ref.invalidate(zoneShipmentsProvider);
                                      ref.invalidate(zoneDriversProvider);
                                    }
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DriverChips extends StatelessWidget {
  const _DriverChips({required this.drivers});

  final List<ZoneDriverSummary> drivers;

  @override
  Widget build(BuildContext context) {
    if (drivers.isEmpty) {
      return const Text('No drivers registered yet.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: drivers.map((d) {
        final label = d.driverName?.isNotEmpty == true
            ? '${d.driverName} · ${d.vehicleType}'
            : '${d.vehiclePlate} · ${d.vehicleType}';
        final zones = d.preferredZones.isNotEmpty
            ? ' · ${d.preferredZones.join(',')}'
            : '';
        return Chip(
          avatar: Icon(
            d.zoneMatch
                ? Icons.star
                : d.isAvailable
                    ? Icons.check_circle
                    : Icons.pause_circle_outline,
            size: 18,
          ),
          label: Text('$label$zones${d.zoneMatch ? ' · recommended' : ''}'),
        );
      }).toList(),
    );
  }
}
