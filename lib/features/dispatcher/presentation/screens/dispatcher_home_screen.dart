import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/demo_zones.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notification/presentation/widgets/notification_bell_button.dart';
import '../../../shipment/presentation/widgets/shipment_list_tile.dart';
import '../providers/dispatcher_providers.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zone Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Zone route map',
            onPressed: () => context.push(RoutePaths.dispatcherMap),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dispatcherProfileProvider);
              ref.invalidate(zoneShipmentsProvider);
              ref.invalidate(zoneDriversProvider);
            },
          ),
          const NotificationBellButton(),
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
                return const Center(
                  child: Text('Dispatcher profile not found'),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(zoneShipmentsProvider);
                  ref.invalidate(zoneDriversProvider);
                },
                child: ListView(
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
                      'Zone: ${DemoZones.labelOf(dispatcher.zone)}',
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
                        '$e\n\nRun 007_dispatcher_ops.sql in Supabase.',
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
                                  label: 'Total',
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
                              'Drivers in zone',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            driversAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (_, __) => const Text('Could not load drivers'),
                              data: (drivers) => _DriverChips(drivers: drivers),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Zone shipments',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (shipments.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32),
                                child: Text(
                                  'No shipments in this zone yet. '
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
                                  onTap: () => context.push(
                                    RoutePaths.dispatcherShipmentDetail(
                                      shipment.id,
                                    ),
                                  ),
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
      return const Text('No drivers registered in this zone.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: drivers.map((d) {
        return Chip(
          avatar: Icon(
            d.isAvailable ? Icons.check_circle : Icons.pause_circle_outline,
            size: 18,
          ),
          label: Text('${d.vehiclePlate} · ${d.vehicleType}'),
        );
      }).toList(),
    );
  }
}
