import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_datasource.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._dataSource);

  final NotificationRemoteDataSource _dataSource;

  @override
  Future<Result<List<AppNotification>>> getMyNotifications() async {
    try {
      final models = await _dataSource.getMyNotifications();
      return Success(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Error(e.message);
    } on AuthException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Stream<List<AppNotification>> watchMyNotifications() {
    return _dataSource.watchMyNotifications().map(
          (models) => models.map((m) => m.toEntity()).toList(),
        );
  }

  @override
  Future<Result<void>> markAsRead(String notificationId) async {
    try {
      await _dataSource.markAsRead(notificationId);
      return const Success(null);
    } on ServerException catch (e) {
      return Error(e.message);
    } on AuthException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Future<Result<void>> markAllAsRead() async {
    try {
      await _dataSource.markAllAsRead();
      return const Success(null);
    } on ServerException catch (e) {
      return Error(e.message);
    } on AuthException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }
}
