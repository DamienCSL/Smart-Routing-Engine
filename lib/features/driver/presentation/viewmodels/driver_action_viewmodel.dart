import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/provider_refresh.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../../../shipment/presentation/providers/shipment_providers.dart';
import '../providers/driver_providers.dart';

class DriverActionState {
  const DriverActionState({
    this.isLoading = false,
    this.errorMessage,
  });

  final bool isLoading;
  final String? errorMessage;

  DriverActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DriverActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DriverActionViewModel extends StateNotifier<DriverActionState> {
  DriverActionViewModel(this._ref) : super(const DriverActionState());

  final Ref _ref;

  Future<bool> updateStatus({
    required String shipmentId,
    required ShipmentStatus newStatus,
    String? note,
  }) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _ref.read(driverTaskRepositoryProvider).updateStatus(
            shipmentId: shipmentId,
            newStatus: newStatus,
            note: note,
          );

      return await result.when(
        success: (_) async {
          await Future.wait([
            refreshAndWaitRef(_ref, driverTaskDetailProvider(shipmentId).future),
            refreshAndWaitRef(_ref, pickupTasksProvider.future),
            refreshAndWaitRef(_ref, deliveryTasksProvider.future),
            refreshAndWaitRef(_ref, shipmentHistoryProvider(shipmentId).future),
          ]);
          return true;
        },
        failure: (message) async {
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

final driverActionViewModelProvider =
    StateNotifierProvider.autoDispose<DriverActionViewModel, DriverActionState>(
  (ref) => DriverActionViewModel(ref),
);
