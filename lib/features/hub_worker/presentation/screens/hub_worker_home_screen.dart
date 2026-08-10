import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/demo_zones.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/utils/provider_refresh.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../driver/domain/entities/driver_task.dart';
import '../../../driver/presentation/widgets/driver_task_tile.dart';
import '../../../ops_map/presentation/screens/driver_navigate_screen.dart';
import '../../../notification/presentation/widgets/notification_bell_button.dart';
import '../providers/hub_worker_providers.dart';

/// Unified ops home for the merged hub-worker role (legacy driver+dispatcher).
class HubWorkerHomeScreen extends ConsumerWidget {
  const HubWorkerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final hubAsync = ref.watch(hubWorkerProfileProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hub Tasks'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_box_outlined),
              tooltip: 'Demo desk',
              onPressed: () => context.push(RoutePaths.hubWorkerDemoDesk),
            ),
            IconButton(
              icon: const Icon(Icons.travel_explore),
              tooltip: 'Track order',
              onPressed: () => context.push(RoutePaths.trackOrder),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scan CN',
              onPressed: () => context.push(RoutePaths.hubWorkerScan),
            ),
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: 'Route to pickup',
              onPressed: () => context.push(RoutePaths.hubWorkerMap),
            ),
            if (!(Env.useDriverApi && !Env.isSupabaseConfigured))
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${profile?.fullName ?? 'Hub Worker'}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      hubAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => Text(
                          Env.useDriverApi
                              ? 'Could not load driver profile from API'
                              : 'Hub profile missing — run 011_hub_workers.sql + demo_staff.sql',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        data: (hub) {
                          if (hub == null) {
                            return Text(
                              Env.useDriverApi
                                  ? 'No t_driver row — run sql/002_driver_mobile_api.sql'
                                  : 'No hub_workers row for this account.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                          final zones = hub.preferredZones.isEmpty
                              ? 'any zone'
                              : hub.preferredZones
                                  .map(DemoZones.labelOf)
                                  .join(', ');
                          return Text(
                            Env.useDriverApi
                                ? 'Branch ${hub.hubId} · $zones'
                                : 'Preferred zones: $zones',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          );
                        },
                      ),
                    ],
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
        ? ref.watch(hubPickupTasksProvider)
        : ref.watch(hubDeliveryTasksProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        if (type == DriverTaskType.pickup) {
          await refreshAndWait(ref, hubPickupTasksProvider.future);
        } else {
          await refreshAndWait(ref, hubDeliveryTasksProvider.future);
        }
      },
      child: tasksAsync.when(
        loading: () => const AppLoadingIndicator(message: 'Loading tasks...'),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              Env.useDriverApi
                  ? '$e\n\nCheck DRIVER_API_URL in .env and that PHP /api/health is up.'
                  : '$e\n\nRun 011_hub_workers.sql then demo_staff.sql, '
                      'and sign in as hub.kk@iposb.demo.',
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
                  Env.useDriverApi
                      ? 'Tap Demo desk → Create CN → Assign to me → jobs appear here. Then scan hops and Track order.'
                      : type == DriverTaskType.pickup
                          ? 'When a customer creates a shipment, jobs appear here.'
                          : 'Delivery jobs appear after the parcel reaches the destination hub.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (Env.useDriverApi) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        context.push(RoutePaths.hubWorkerDemoDesk),
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('Open Demo desk'),
                  ),
                ],
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
                  RoutePaths.hubWorkerTaskDetail(task.id),
                ),
                onRoute: () => context.push(
                  RoutePaths.hubWorkerNavigate,
                  extra: DriverNavigateArgs.fromTask(task),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
