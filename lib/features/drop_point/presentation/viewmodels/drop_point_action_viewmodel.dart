import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/enums/shipment_status.dart';
import '../providers/drop_point_providers.dart';

class DropPointActionState {
  const DropPointActionState({this.isLoading = false, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;

  DropPointActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DropPointActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DropPointActionViewModel extends StateNotifier<DropPointActionState> {
  DropPointActionViewModel(this._ref) : super(const DropPointActionState());

  final Ref _ref;

  Future<bool> updateStatus({
    required String shipmentId,
    required ShipmentStatus newStatus,
    String? note,
  }) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _ref.read(dropPointRepositoryProvider).updateStatus(
            shipmentId: shipmentId,
            newStatus: newStatus,
            note: note,
          );

      return result.when(
        success: (_) {
          _ref.invalidate(dropPointTaskDetailProvider(shipmentId));
          _ref.invalidate(originIntakeTasksProvider);
          _ref.invalidate(destinationIntakeTasksProvider);
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
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }
}

final dropPointActionViewModelProvider = StateNotifierProvider.autoDispose<
    DropPointActionViewModel, DropPointActionState>(
  (ref) => DropPointActionViewModel(ref),
);
