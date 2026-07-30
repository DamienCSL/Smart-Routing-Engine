import '../../../../core/utils/result.dart';
import '../../../../shared/enums/user_role.dart';
import '../entities/user_profile.dart';

/// Contract for authentication and session management.
abstract class AuthRepository {
  Stream<bool> get authStateChanges;

  bool get isAuthenticated;

  String? get currentUserId;

  Future<Result<UserProfile>> signIn({
    required String email,
    required String password,
  });

  Future<Result<UserProfile>> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
  });

  Future<Result<void>> signOut();

  Future<Result<UserProfile>> getCurrentProfile();

  Future<Result<UserProfile>> updateProfile({
    required String fullName,
    String? phone,
  });
}
