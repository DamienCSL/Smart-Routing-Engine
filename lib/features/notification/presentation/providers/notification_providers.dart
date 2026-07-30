import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
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
    // FCM handles push in Driver API mode; no Supabase notification table.
    return Stream.value(const <AppNotification>[]);
  }
  final auth = ref.watch(authRepositoryProvider);
  if (!auth.isAuthenticated) {
    return Stream.value(const <AppNotification>[]);
  }
  return ref.watch(notificationRepositoryProvider).watchMyNotifications();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final async = ref.watch(myNotificationsProvider);
  return async.maybeWhen(
    data: (items) => items.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});
