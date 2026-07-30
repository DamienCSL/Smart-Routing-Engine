import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notification/presentation/widgets/notification_bell_button.dart';
import '../../../shipment/presentation/widgets/shipment_status_chip.dart';
import '../../domain/entities/drop_point_task.dart';
import '../providers/drop_point_providers.dart';

class DropPointHomeScreen extends ConsumerWidget {
  const DropPointHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Drop Point'),
          actions: [
            const NotificationBellButton(),
            IconButton(
              icon: const Icon(Icons.person_outlined),
              onPressed: () => context.push(RoutePaths.profile),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Origin Intake', icon: Icon(Icons.upload_outlined)),
              Tab(text: 'Dest Intake', icon: Icon(Icons.download_outlined)),
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
                    'Hello, ${profile?.fullName ?? 'Operator'}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const Expanded(
                  child: TabBarView(
                    children: [
                      _DropPointTaskList(
                        queueType: DropPointQueueType.originIntake,
                      ),
                      _DropPointTaskList(
                        queueType: DropPointQueueType.destinationIntake,
                      ),
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

class _DropPointTaskList extends ConsumerWidget {
  const _DropPointTaskList({required this.queueType});

  final DropPointQueueType queueType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = queueType == DropPointQueueType.originIntake
        ? ref.watch(originIntakeTasksProvider)
        : ref.watch(destinationIntakeTasksProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        if (queueType == DropPointQueueType.originIntake) {
          ref.invalidate(originIntakeTasksProvider);
        } else {
          ref.invalidate(destinationIntakeTasksProvider);
        }
      },
      child: tasksAsync.when(
        loading: () => const AppLoadingIndicator(message: 'Loading parcels...'),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '$e\n\nRun 008_drop_point_storekeeper_ops.sql and demo_drop_points.sql.',
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
                Icon(Icons.store_outlined, size: 56, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  queueType == DropPointQueueType.originIntake
                      ? 'No origin intake parcels'
                      : 'No destination intake parcels',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  queueType == DropPointQueueType.originIntake
                      ? 'Parcels appear after the pickup driver hands off to this drop point.'
                      : 'Parcels appear after the storekeeper marks in-transit / destination hub.',
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
              final s = task.shipment;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    s.trackingNumber,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${s.originCity} → ${s.destinationCity}'),
                  trailing: ShipmentStatusChip(status: s.status),
                  onTap: () => context.push(
                    RoutePaths.dropPointTaskDetail(task.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
