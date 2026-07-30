import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/driver_api_session.dart';
import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
});

/// Stream of authentication state — `true` when session exists.
final authStateProvider = StreamProvider<bool>((ref) {
  if (Env.useDriverApi && !Env.isSupabaseConfigured) {
    final session = ref.watch(driverApiSessionProvider);
    return Stream<bool>.value(session != null);
  }
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Current user profile — refreshes when auth state changes.
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  ref.watch(authStateProvider);

  if (Env.useDriverApi && !Env.isSupabaseConfigured) {
    final session = ref.watch(driverApiSessionProvider);
    if (session == null) return null;
    return UserProfile(
      id: session.uid,
      email: session.email.isNotEmpty
          ? session.email
          : '${session.uid}@iposb.local',
      fullName: session.displayName,
      role: session.role,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  final repository = ref.watch(authRepositoryProvider);
  if (!repository.isAuthenticated) return null;

  final result = await repository.getCurrentProfile();
  return result.when(
    success: (profile) => profile,
    failure: (_) => null,
  );
});
