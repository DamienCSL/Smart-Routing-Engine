import '../../../../shared/enums/user_role.dart';
import '../../domain/entities/user_profile.dart';

/// Maps `users` table rows (with joined `roles`) to [UserProfile].
class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roleName,
    required this.isActive,
    required this.createdAt,
    this.phone,
    this.avatarUrl,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final roles = json['roles'] as Map<String, dynamic>?;
    final roleName = roles?['name'] as String? ?? 'customer';

    return UserProfileModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      roleName: roleName,
      avatarUrl: json['avatar_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String roleName;
  final String? avatarUrl;
  final bool isActive;
  final DateTime createdAt;

  UserProfile toEntity() {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName,
      phone: phone,
      role: UserRole.fromValue(roleName),
      avatarUrl: avatarUrl,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toUpdateJson({
    required String fullName,
    String? phone,
  }) {
    return {
      'full_name': fullName,
      'phone': phone,
    };
  }
}
