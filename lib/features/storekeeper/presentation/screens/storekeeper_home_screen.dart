import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notification/presentation/widgets/notification_bell_button.dart';
import '../../../shipment/presentation/widgets/shipment_status_chip.dart';
import '../providers/storekeeper_providers.dart';

class StorekeeperHomeScreen extends ConsumerWidget {
  const StorekeeperHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final tasksAsync = ref.watch(hubTasksProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hub Sorting'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(hubTasksProvider),
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
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(hubTasksProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Hello, ${profile?.fullName ?? 'Storekeeper'}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sort parcels and dispatch outbound lanes',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                tasksAsync.when(
                  loading: () => const AppLoadingIndicator(),
                  error: (e, _) => Text(
                    '$e\n\nRun 008_drop_point_storekeeper_ops.sql.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  data: (tasks) {
                    if (tasks.isEmpty) {
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
                              'No hub parcels yet',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Parcels appear after the origin drop point forwards them to the hub.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (final task in tasks)
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                task.trackingNumber,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${task.shipment.originCity} → ${task.shipment.destinationCity}',
                              ),
                              trailing: ShipmentStatusChip(status: task.status),
                              onTap: () => context.push(
                                RoutePaths.storekeeperTaskDetail(task.id),
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
      ),
    );
  }
}
