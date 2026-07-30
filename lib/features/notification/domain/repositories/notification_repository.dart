import '../../../../core/utils/result.dart';
import '../entities/app_notification.dart';

abstract class NotificationRepository {
  Future<Result<List<AppNotification>>> getMyNotifications();

  Stream<List<AppNotification>> watchMyNotifications();

  Future<Result<void>> markAsRead(String notificationId);

  Future<Result<void>> markAllAsRead();
}
