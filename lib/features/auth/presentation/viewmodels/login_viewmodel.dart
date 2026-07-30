import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/driver_api_session.dart';
import '../providers/auth_providers.dart';

class LoginState {
  const LoginState({
    this.isLoading = false,
    this.errorMessage,
  });

  final bool isLoading;
  final String? errorMessage;

  LoginState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class LoginViewModel extends StateNotifier<LoginState> {
  LoginViewModel(this._ref) : super(const LoginState());

  final Ref _ref;

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Pure Driver API mode (IPOSB MySQL master — no Supabase).
      if (Env.useDriverApi && !Env.isSupabaseConfigured) {
        final trimmed = email.trim();
        if (trimmed.isEmpty) {
          state = state.copyWith(errorMessage: 'Email is required');
          return false;
        }
        if (password.trim().isEmpty) {
          state = state.copyWith(errorMessage: 'Password is required');
          return false;
        }

        // Escape hatch for ops desk without seeded users.
        if (trimmed.toLowerCase() == 'demo@iposb.demo' ||
            trimmed.toLowerCase() == 'demo') {
          await _ref.read(driverApiSessionProvider.notifier).signInDemo(
                displayName: 'Demo Driver',
              );
          return true;
        }

        await _ref.read(driverApiSessionProvider.notifier).signInWithPassword(
              email: trimmed,
              password: password,
            );
        return true;
      }

      final result = await _ref.read(authRepositoryProvider).signIn(
            email: email,
            password: password,
          );

      return result.when(
        success: (_) {
          if (Env.useDriverApi) {
            _ref.read(driverApiSessionProvider.notifier).signInDemo();
          }
          _ref.invalidate(currentUserProfileProvider);
          return true;
        },
        failure: (message) {
          state = state.copyWith(errorMessage: message);
          return false;
        },
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }
}

final loginViewModelProvider =
    StateNotifierProvider<LoginViewModel, LoginState>((ref) {
  return LoginViewModel(ref);
});
