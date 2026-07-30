import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notification/presentation/widgets/notification_bell_button.dart';
import '../../../shipment/presentation/providers/shipment_providers.dart';
import '../../../shipment/presentation/widgets/shipment_list_tile.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final shipmentsAsync = ref.watch(customerShipmentsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shipments'),
        actions: [
          const NotificationBellButton(),
          IconButton(
            icon: const Icon(Icons.person_outlined),
            tooltip: 'Profile',
            onPressed: () => context.push(RoutePaths.profile),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.customerCreateShipment),
        icon: const Icon(Icons.add),
        label: const Text('New Shipment'),
      ),
      body: profileAsync.when(
        loading: () => const AppLoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(customerShipmentsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                Text(
                  'Hello, ${profile?.fullName ?? 'Customer'}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create and track parcels in realtime',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                shipmentsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: AppLoadingIndicator(message: 'Loading shipments...'),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      'Could not load shipments.\n$e\n\n'
                      'Make sure you ran 001, 002, and 003 SQL migrations.',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                  data: (shipments) {
                    if (shipments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 56,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No shipments yet',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap New Shipment to create your first parcel.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (final shipment in shipments)
                          ShipmentListTile(
                            shipment: shipment,
                            onTap: () => context.push(
                              RoutePaths.customerShipmentDetail(shipment.id),
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
      ),
    );
  }
}
