import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/driver_api_session.dart';
import '../../../../shared/enums/user_role.dart';
import '../providers/auth_providers.dart';

class RegisterState {
  const RegisterState({
    this.isLoading = false,
    this.errorMessage,
    this.selectedRole = UserRole.customer,
  });

  final bool isLoading;
  final String? errorMessage;
  final UserRole selectedRole;

  RegisterState copyWith({
    bool? isLoading,
    String? errorMessage,
    UserRole? selectedRole,
    bool clearError = false,
  }) {
    return RegisterState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedRole: selectedRole ?? this.selectedRole,
    );
  }
}

class RegisterViewModel extends StateNotifier<RegisterState> {
  RegisterViewModel(this._ref) : super(const RegisterState());

  final Ref _ref;

  void setRole(UserRole role) {
    state = state.copyWith(selectedRole: role);
  }

  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    if (state.isLoading) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (Env.useDriverApi && !Env.isSupabaseConfigured) {
        final role = state.selectedRole == UserRole.hubWorker ||
                state.selectedRole == UserRole.driver
            ? UserRole.hubWorker
            : UserRole.customer;
        await _ref.read(driverApiSessionProvider.notifier).signUp(
              email: email,
              password: password,
              fullName: fullName,
              role: role,
              phone: phone,
            );
        _ref.invalidate(currentUserProfileProvider);
        return true;
      }

      final result = await _ref.read(authRepositoryProvider).signUp(
            email: email,
            password: password,
            fullName: fullName,
            role: state.selectedRole,
            phone: phone,
          );

      return result.when(
        success: (_) {
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

final registerViewModelProvider =
    StateNotifierProvider<RegisterViewModel, RegisterState>((ref) {
  return RegisterViewModel(ref);
});
