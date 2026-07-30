import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/enums/user_role.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dataSource);

  final AuthRemoteDataSource _dataSource;

  @override
  Stream<bool> get authStateChanges => _dataSource.authStateChanges;

  @override
  bool get isAuthenticated => _dataSource.isAuthenticated;

  @override
  String? get currentUserId => _dataSource.currentUserId;

  @override
  Future<Result<UserProfile>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final model = await _dataSource.signIn(email: email, password: password);
      return Success(model.toEntity());
    } on AuthException catch (e) {
      return Error(e.message);
    } on ServerException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Future<Result<UserProfile>> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
  }) async {
    try {
      final model = await _dataSource.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        phone: phone,
      );
      return Success(model.toEntity());
    } on AuthException catch (e) {
      return Error(e.message);
    } on ServerException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _dataSource.signOut();
      return const Success(null);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Future<Result<UserProfile>> getCurrentProfile() async {
    final userId = _dataSource.currentUserId;
    if (userId == null) {
      return const Error('Not authenticated');
    }

    try {
      final model = await _dataSource.getProfile(userId);
      return Success(model.toEntity());
    } on ServerException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }

  @override
  Future<Result<UserProfile>> updateProfile({
    required String fullName,
    String? phone,
  }) async {
    final userId = _dataSource.currentUserId;
    if (userId == null) {
      return const Error('Not authenticated');
    }

    try {
      final model = await _dataSource.updateProfile(
        userId: userId,
        fullName: fullName,
        phone: phone,
      );
      return Success(model.toEntity());
    } on ServerException catch (e) {
      return Error(e.message);
    } catch (e) {
      return Error(e.toString());
    }
  }
}
