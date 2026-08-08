import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/driver_api_providers.dart';
import '../../../../core/network/driver_api_session.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
      return NotificationRemoteDataSource(ref.watch(supabaseClientProvider));
    });

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    ref.watch(notificationRemoteDataSourceProvider),
  );
});

final myNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  ref.watch(authStateProvider);
  if (Env.useDriverApi && !Env.isSupabaseConfigured) {
    final session = ref.watch(driverApiSessionProvider);
    if (session == null) return Stream.value(const <AppNotification>[]);
    final api = ref.watch(driverApiClientProvider);

    Future<List<AppNotification>> load() async {
      final rows = await api.listNotifications();
      return rows.map((row) {
        final cn = row['cnNo']?.toString();
        return AppNotification(
          id: '${row['id']}',
          userId: '${session.userId}',
          shipmentId: cn?.isEmpty == true ? null : cn,
          title: (row['title'] ?? 'Shipment update').toString(),
          body: (row['body'] ?? '').toString(),
          type: cn == null ? 'general' : 'status',
          isRead: row['isRead'] == true || row['isRead'] == 1,
          createdAt:
              DateTime.tryParse('${row['createdAt'] ?? ''}') ?? DateTime.now(),
        );
      }).toList();
    }

    Stream<List<AppNotification>> poll() async* {
      yield await load();
      yield* Stream.periodic(
        const Duration(seconds: 20),
      ).asyncMap((_) => load());
    }

    return poll();
  }
  final auth = ref.watch(authRepositoryProvider);
  if (!auth.isAuthenticated) {
    return Stream.value(const <AppNotification>[]);
  }
  return ref.watch(notificationRepositoryProvider).watchMyNotifications();
});

Future<void> markNotificationAsRead(WidgetRef ref, String id) async {
  if (Env.useDriverApi && !Env.isSupabaseConfigured) {
    await ref.read(driverApiClientProvider).postJson('/notifications/$id/read');
    ref.invalidate(myNotificationsProvider);
    return;
  }
  final result = await ref.read(notificationRepositoryProvider).markAsRead(id);
  result.when(success: (_) {}, failure: (message) => throw Exception(message));
  ref.invalidate(myNotificationsProvider);
}

Future<void> markAllNotificationsAsRead(
  WidgetRef ref,
  List<AppNotification> items,
) async {
  if (Env.useDriverApi && !Env.isSupabaseConfigured) {
    final api = ref.read(driverApiClientProvider);
    await Future.wait(
      items
          .where((item) => !item.isRead)
          .map((item) => api.postJson('/notifications/${item.id}/read')),
    );
    ref.invalidate(myNotificationsProvider);
    return;
  }
  final result = await ref.read(notificationRepositoryProvider).markAllAsRead();
  result.when(success: (_) {}, failure: (message) => throw Exception(message));
  ref.invalidate(myNotificationsProvider);
}

final unreadNotificationCountProvider = Provider<int>((ref) {
  final async = ref.watch(myNotificationsProvider);
  return async.maybeWhen(
    data: (items) => items.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});
