import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notification/presentation/widgets/notification_bell_button.dart';
import '../../domain/entities/driver_task.dart';
import '../providers/driver_providers.dart';
import '../widgets/driver_task_tile.dart';

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Driver Tasks'),
          actions: [
            IconButton(
              icon: const Icon(Icons.map_outlined),
            tooltip: 'Route to pickup',
            onPressed: () => context.push(RoutePaths.driverMap),
            ),
            const NotificationBellButton(),
            IconButton(
              icon: const Icon(Icons.person_outlined),
              tooltip: 'Profile',
              onPressed: () => context.push(RoutePaths.profile),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pickup', icon: Icon(Icons.upload_outlined)),
              Tab(text: 'Delivery', icon: Icon(Icons.download_outlined)),
            ],
          ),
        ),
        body: profileAsync.when(
          loading: () => const AppLoadingIndicator(),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (profile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Hello, ${profile?.fullName ?? 'Driver'}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const Expanded(
                  child: TabBarView(
                    children: [
                      _TaskList(type: DriverTaskType.pickup),
                      _TaskList(type: DriverTaskType.delivery),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.type});

  final DriverTaskType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = type == DriverTaskType.pickup
        ? ref.watch(pickupTasksProvider)
        : ref.watch(deliveryTasksProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        if (type == DriverTaskType.pickup) {
          ref.invalidate(pickupTasksProvider);
        } else {
          ref.invalidate(deliveryTasksProvider);
        }
      },
      child: tasksAsync.when(
        loading: () => const AppLoadingIndicator(message: 'Loading tasks...'),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '$e\n\nMake sure you ran 006_driver_ops.sql and signed in as a seeded driver.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(48),
              children: [
                Icon(
                  type == DriverTaskType.pickup
                      ? Icons.inventory_2_outlined
                      : Icons.local_shipping_outlined,
                  size: 56,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  type == DriverTaskType.pickup
                      ? 'No active pickup jobs'
                      : 'No active delivery jobs',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  type == DriverTaskType.pickup
                      ? 'New assignments appear here after a customer creates a '
                          'shipment (Kota Kinabalu Metro → Sandakan).\n\n'
                          'If a shipment was already assigned, run 006_driver_ops.sql in Supabase so drivers can read their tasks, then pull to refresh.'
                      : 'Jobs appear after the pickup driver hands off to the drop point.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return DriverTaskTile(
                task: task,
                onTap: () => context.push(
                  RoutePaths.driverTaskDetail(task.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
