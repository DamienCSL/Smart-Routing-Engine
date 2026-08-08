import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(myNotificationsProvider);
    final theme = Theme.of(context);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                try {
                  await markAllNotificationsAsRead(
                    ref,
                    notificationsAsync.valueOrNull ?? const [],
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All marked as read')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$e')));
                }
              },
              child: const Text('Mark all read'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myNotificationsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myNotificationsProvider),
        child: notificationsAsync.when(
          loading: () => const AppLoadingIndicator(message: 'Loading...'),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '$e\n\nRun 009_notifications.sql if needed.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(48),
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 56,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Assignment and status updates will appear here in realtime.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return _NotificationTile(
                  notification: item,
                  onTap: () => _onTap(context, ref, item),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    AppNotification item,
  ) async {
    if (!item.isRead) {
      await markNotificationAsRead(ref, item.id);
    }
    final role = ref.read(currentUserProfileProvider).valueOrNull?.role;
    if (context.mounted &&
        role == UserRole.customer &&
        item.shipmentId != null) {
      context.push(RoutePaths.customerShipmentDetail(item.shipmentId!));
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateFormat.yMMMd().add_jm().format(
      notification.createdAt.toLocal(),
    );

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: notification.isRead
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primaryContainer,
        child: Icon(
          _iconFor(notification.type),
          color: notification.isRead
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(notification.body),
          const SizedBox(height: 4),
          Text(
            time,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: notification.isRead
          ? null
          : Icon(Icons.circle, size: 10, color: theme.colorScheme.primary),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'task' => Icons.assignment_outlined,
      'status' => Icons.local_shipping_outlined,
      _ => Icons.notifications_outlined,
    };
  }
}
