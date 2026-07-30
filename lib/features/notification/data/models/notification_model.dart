import '../../domain/entities/app_notification.dart';

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.shipmentId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      shipmentId: json['shipment_id'] as String?,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String? ?? 'task',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String userId;
  final String? shipmentId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  AppNotification toEntity() {
    return AppNotification(
      id: id,
      userId: userId,
      shipmentId: shipmentId,
      title: title,
      body: body,
      type: type,
      isRead: isRead,
      createdAt: createdAt,
    );
  }
}
