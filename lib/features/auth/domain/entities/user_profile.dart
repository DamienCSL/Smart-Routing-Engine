import 'package:equatable/equatable.dart';

import '../../../../shared/enums/user_role.dart';

/// Domain entity representing an authenticated user profile.
class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.phone,
    this.avatarUrl,
    this.accountNo,
    this.driverId,
    this.dispatcherId,
    this.preferredZones = const [],
  });

  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final UserRole role;
  final String? avatarUrl;
  final bool isActive;
  final DateTime createdAt;

  /// Customer account number (IPOSB `cust_ac_no`).
  final String? accountNo;
  final int? driverId;
  final int? dispatcherId;
  final List<String> preferredZones;

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? accountNo,
    List<String>? preferredZones,
  }) {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive,
      createdAt: createdAt,
      accountNo: accountNo ?? this.accountNo,
      driverId: driverId,
      dispatcherId: dispatcherId,
      preferredZones: preferredZones ?? this.preferredZones,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        fullName,
        phone,
        role,
        avatarUrl,
        isActive,
        createdAt,
        accountNo,
        driverId,
        dispatcherId,
        preferredZones,
      ];
}
