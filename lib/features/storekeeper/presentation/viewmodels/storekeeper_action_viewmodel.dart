import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/enums/shipment_status.dart';
import '../providers/storekeeper_providers.dart';

class StorekeeperActionState {
  const StorekeeperActionState({this.isLoading = false, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;

  StorekeeperActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StorekeeperActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class StorekeeperActionViewModel
    extends StateNotifier<StorekeeperActionState> {
  StorekeeperActionViewModel(this._ref) : super(const StorekeeperActionState());

  final Ref _ref;

  Future<bool> updateStatus({
    required String shipmentId,
    required ShipmentStatus newStatus,
    String? note,
  }) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result =
          await _ref.read(storekeeperRepositoryProvider).updateStatus(
                shipmentId: shipmentId,
                newStatus: newStatus,
                note: note,
              );

      return result.when(
        success: (_) {
          _ref.invalidate(storekeeperTaskDetailProvider(shipmentId));
          _ref.invalidate(hubTasksProvider);
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

final storekeeperActionViewModelProvider = StateNotifierProvider.autoDispose<
    StorekeeperActionViewModel, StorekeeperActionState>(
  (ref) => StorekeeperActionViewModel(ref),
);
