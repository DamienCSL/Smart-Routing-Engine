import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/enums/user_role.dart';
import '../models/user_profile_model.dart';

/// Supabase-backed authentication data source.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 20);

  Stream<bool> get authStateChanges =>
      _client.auth.onAuthStateChange.map((event) => event.session != null);

  bool get isAuthenticated => _client.auth.currentSession != null;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<UserProfileModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.info('Auth: signing in $email');
      final response = await _client.auth
          .signInWithPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(_timeout);

      final userId = response.user?.id;
      if (userId == null) {
        throw const AuthException('Sign in failed — no user returned');
      }

      return ensureProfile(
        userId: userId,
        email: email.trim(),
        fullName: response.user?.userMetadata?['full_name'] as String? ??
            email.split('@').first,
        role: UserRole.fromValue(
          response.user?.userMetadata?['role'] as String? ?? 'customer',
        ),
        phone: response.user?.userMetadata?['phone'] as String?,
      );
    } on AuthException {
      rethrow;
    } on AuthApiException catch (e) {
      throw AuthException(e.message);
    } on TimeoutException {
      throw const AuthException(
        'Sign in timed out. Check your internet connection and try again.',
      );
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  Future<UserProfileModel> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
  }) async {
    try {
      AppLogger.info('Auth: signing up $email as ${role.value}');

      final response = await _client.auth
          .signUp(
            email: email.trim(),
            password: password,
            data: {
              'full_name': fullName.trim(),
              'role': role.value,
              if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
            },
          )
          .timeout(_timeout);

      final userId = response.user?.id;
      if (userId == null) {
        throw const AuthException('Sign up failed — no user returned');
      }

      AppLogger.info(
        'Auth: signup ok user=$userId session=${response.session != null}',
      );

      // Email confirmation may delay session creation.
      if (response.session == null) {
        throw const AuthException(
          'Account created, but email confirmation is still enabled. '
          'In Supabase: Authentication → Providers → Email → turn OFF '
          '"Confirm email", then try again (or sign in after confirming).',
        );
      }

      return ensureProfile(
        userId: userId,
        email: email.trim(),
        fullName: fullName.trim(),
        role: role,
        phone: phone,
      );
    } on AuthException {
      rethrow;
    } on AuthApiException catch (e) {
      throw AuthException(_mapAuthError(e.message, e.code));
    } on AuthRetryableFetchException catch (e) {
      throw AuthException(
        'Cannot reach Supabase (${e.message}). '
        'If this keeps happening on the emulator, try Chrome: flutter run -d chrome',
      );
    } on TimeoutException {
      throw const AuthException(
        'Sign up timed out. Your Wi-Fi may be fine — check Supabase: '
        'Authentication → Providers → Email must be ENABLED. '
        'Also try: flutter run -d chrome',
      );
    } catch (e) {
      throw AuthException(_mapAuthError(e.toString(), null));
    }
  }

  static String _mapAuthError(String message, String? code) {
    final lower = message.toLowerCase();
    if (code == 'email_provider_disabled' ||
        lower.contains('email signups are disabled') ||
        lower.contains('email_provider_disabled')) {
      return 'Email signups are disabled in Supabase. '
          'Go to Authentication → Providers → Email → Enable, then try again.';
    }
    return message;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Loads profile; creates it if the DB trigger has not run yet.
  Future<UserProfileModel> ensureProfile({
    required String userId,
    required String email,
    required String fullName,
    required UserRole role,
    String? phone,
  }) async {
    try {
      return await getProfile(userId);
    } catch (e) {
      AppLogger.info('Auth: profile missing ($e) — creating fallback row');
    }

    try {
      final roleId = await _resolveRoleId(role);

      await _client
          .from('users')
          .upsert({
            'id': userId,
            'email': email,
            'full_name': fullName,
            'phone':
                (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
            'role_id': roleId,
          })
          .timeout(_timeout);

      return await getProfile(userId);
    } on PostgrestException catch (e) {
      throw ServerException(
        'Could not create profile. Did you run 001_initial_schema.sql '
        'and 002_auth_rls.sql? (${e.message})',
      );
    } on TimeoutException {
      throw const ServerException('Profile setup timed out. Please try again.');
    }
  }

  Future<UserProfileModel> getProfile(String userId) async {
    try {
      final data = await _client
          .from('users')
          .select('*, roles(name, label)')
          .eq('id', userId)
          .single()
          .timeout(_timeout);

      return UserProfileModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Loading profile timed out.');
    }
  }

  Future<UserProfileModel> updateProfile({
    required String userId,
    required String fullName,
    String? phone,
  }) async {
    try {
      await _client
          .from('users')
          .update({
            'full_name': fullName,
            'phone': phone,
          })
          .eq('id', userId)
          .timeout(_timeout);

      return getProfile(userId);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on TimeoutException {
      throw const ServerException('Updating profile timed out.');
    }
  }

  Future<String> _resolveRoleId(UserRole role) async {
    final data = await _client
        .from('roles')
        .select('id')
        .eq('name', role.value)
        .maybeSingle()
        .timeout(_timeout);

    final id = data?['id'] as String?;
    if (id != null) return id;

    final fallback = await _client
        .from('roles')
        .select('id')
        .eq('name', UserRole.customer.value)
        .single()
        .timeout(_timeout);

    return fallback['id'] as String;
  }
}
