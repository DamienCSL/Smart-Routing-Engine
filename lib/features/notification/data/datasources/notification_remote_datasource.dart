import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../models/notification_model.dart';

class NotificationRemoteDataSource {
  NotificationRemoteDataSource(this._client);

  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 20);

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AuthException('Not authenticated');
    }
    return id;
  }

  Future<List<NotificationModel>> getMyNotifications() async {
    try {
      final userId = _userId;
      final data = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(_timeout);

      final list = (data as List<dynamic>)
          .map((row) =>
              NotificationModel.fromJson(row as Map<String, dynamic>))
          .toList();

      AppLogger.info('Notifications loaded: ${list.length}');
      return list;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading notifications timed out.');
    }
  }

  /// REST first, then re-fetch on any notifications table change.
  Stream<List<NotificationModel>> watchMyNotifications() async* {
    Future<List<NotificationModel>> load() => getMyNotifications();

    yield await load();

    yield* _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .asyncMap((_) => load());
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', _userId)
          .timeout(_timeout);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Marking notification read timed out.');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _userId)
          .eq('is_read', false)
          .timeout(_timeout);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Marking all notifications read timed out.');
    }
  }
}
