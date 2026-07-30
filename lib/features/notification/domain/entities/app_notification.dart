import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.shipmentId,
  });

  final String id;
  final String userId;
  final String? shipmentId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, isRead, createdAt];
}
