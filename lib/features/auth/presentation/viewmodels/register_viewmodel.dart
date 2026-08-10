import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/demo_zones.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/driver_api_session.dart';
import '../../../../shared/enums/user_role.dart';
import '../providers/auth_providers.dart';

class RegisterState {
  const RegisterState({
    this.isLoading = false,
    this.errorMessage,
    this.pendingMessage,
    this.selectedRole = UserRole.customer,
    this.preferredZones = const [],
  });

  final bool isLoading;
  final String? errorMessage;
  final String? pendingMessage;
  final UserRole selectedRole;
  final List<String> preferredZones;

  bool get needsZones =>
      selectedRole == UserRole.hubWorker ||
      selectedRole == UserRole.driver ||
      selectedRole == UserRole.dispatcher;

  RegisterState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? pendingMessage,
    UserRole? selectedRole,
    List<String>? preferredZones,
    bool clearError = false,
    bool clearPending = false,
  }) {
    return RegisterState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingMessage:
          clearPending ? null : (pendingMessage ?? this.pendingMessage),
      selectedRole: selectedRole ?? this.selectedRole,
      preferredZones: preferredZones ?? this.preferredZones,
    );
  }
}

class RegisterViewModel extends StateNotifier<RegisterState> {
  RegisterViewModel(this._ref) : super(const RegisterState());

  final Ref _ref;

  void setRole(UserRole role) {
    state = state.copyWith(
      selectedRole: role,
      preferredZones: role == UserRole.customer ? const [] : state.preferredZones,
    );
  }

  void toggleZone(String zone) {
    final next = [...state.preferredZones];
    if (next.contains(zone)) {
      next.remove(zone);
    } else {
      next.add(zone);
    }
    state = state.copyWith(preferredZones: next);
  }

  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    if (state.isLoading) return false;

    state = state.copyWith(isLoading: true, clearError: true, clearPending: true);

    try {
      if (Env.useDriverApi && !Env.isSupabaseConfigured) {
        if (state.needsZones && state.preferredZones.isEmpty) {
          state = state.copyWith(
            errorMessage: 'Select at least one preferred zone',
          );
          return false;
        }
        final role = state.selectedRole;
        await _ref.read(driverApiSessionProvider.notifier).signUp(
              email: email,
              password: password,
              fullName: fullName,
              role: role,
              phone: phone,
              preferredZones:
                  state.needsZones ? state.preferredZones : null,
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
    } on PendingVerificationException catch (e) {
      state = state.copyWith(pendingMessage: e.message);
      return false;
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

/// Zones shown on register / profile pickers.
List<String> get registerZoneChoices => DemoZones.all;
