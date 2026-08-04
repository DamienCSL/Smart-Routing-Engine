import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/driver_api_providers.dart';
import '../../../../core/network/driver_api_session.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/provider_refresh.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/enums/shipment_status.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../driver/domain/entities/driver_task.dart';
import '../../../shipment/presentation/providers/shipment_providers.dart';
import '../../data/datasources/hub_worker_api_datasource.dart';
import '../../data/datasources/hub_worker_remote_datasource.dart';

final hubWorkerApiDataSourceProvider = Provider<HubWorkerApiDataSource>((ref) {
  return HubWorkerApiDataSource(ref.watch(driverApiClientProvider));
});

final hubWorkerRemoteDataSourceProvider =
    Provider<HubWorkerRemoteDataSource?>((ref) {
  if (Env.useDriverApi || !Env.isSupabaseConfigured) return null;
  return HubWorkerRemoteDataSource(ref.watch(supabaseClientProvider));
});

final hubWorkerProfileProvider =
    FutureProvider<({String id, String hubId, List<String> preferredZones})?>(
        (ref) async {
  ref.watch(authStateProvider);
  try {
    if (Env.useDriverApi) {
      final session = ref.watch(driverApiSessionProvider);
      if (session == null || session.role == UserRole.dispatcher ||
          session.role == UserRole.customer) {
        return null;
      }
      return await ref.watch(hubWorkerApiDataSourceProvider).getCurrentProfile();
    }
    final ds = ref.watch(hubWorkerRemoteDataSourceProvider);
    if (ds == null) return null;
    return await ds.getCurrentProfile();
  } catch (_) {
    return null;
  }
});

final hubPickupTasksProvider = StreamProvider<List<DriverTask>>((ref) {
  ref.watch(authStateProvider);
  if (Env.useDriverApi) {
    return ref
        .watch(hubWorkerApiDataSourceProvider)
        .watchTasks(type: DriverTaskType.pickup);
  }
  final ds = ref.watch(hubWorkerRemoteDataSourceProvider);
  if (ds == null) return Stream.value(const []);
  return ds.watchTasks(type: DriverTaskType.pickup);
});

final hubDeliveryTasksProvider = StreamProvider<List<DriverTask>>((ref) {
  ref.watch(authStateProvider);
  if (Env.useDriverApi) {
    return ref
        .watch(hubWorkerApiDataSourceProvider)
        .watchTasks(type: DriverTaskType.delivery);
  }
  final ds = ref.watch(hubWorkerRemoteDataSourceProvider);
  if (ds == null) return Stream.value(const []);
  return ds.watchTasks(type: DriverTaskType.delivery);
});

final hubWorkerTaskDetailProvider =
    FutureProvider.family<DriverTask?, String>((ref, shipmentId) async {
  try {
    if (Env.useDriverApi) {
      return await ref
          .watch(hubWorkerApiDataSourceProvider)
          .getTaskByShipmentId(shipmentId);
    }
    final ds = ref.watch(hubWorkerRemoteDataSourceProvider);
    if (ds == null) return null;
    return await ds.getTaskByShipmentId(shipmentId);
  } catch (_) {
    return null;
  }
});

class HubWorkerActionState {
  const HubWorkerActionState({this.isLoading = false, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;

  HubWorkerActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HubWorkerActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class HubWorkerActionViewModel extends StateNotifier<HubWorkerActionState> {
  HubWorkerActionViewModel(this._ref) : super(const HubWorkerActionState());

  final Ref _ref;

  Future<bool> updateStatus({
    required String shipmentId,
    required ShipmentStatus newStatus,
    String? note,
    String? apiStatus,
  }) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (Env.useDriverApi) {
        await _ref.read(hubWorkerApiDataSourceProvider).updateStatus(
              shipmentId: shipmentId,
              newStatus: newStatus,
              note: note,
              apiStatus: apiStatus,
            );
      } else {
        final ds = _ref.read(hubWorkerRemoteDataSourceProvider);
        if (ds == null) throw Exception('No hub worker backend configured');
        await ds.updateStatus(
          shipmentId: shipmentId,
          newStatus: newStatus,
          note: note,
        );
      }
      await Future.wait([
        refreshAndWaitRef(_ref, hubWorkerTaskDetailProvider(shipmentId).future),
        refreshAndWaitRef(_ref, hubPickupTasksProvider.future),
        refreshAndWaitRef(_ref, hubDeliveryTasksProvider.future),
        refreshAndWaitRef(_ref, shipmentHistoryProvider(shipmentId).future),
      ]);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }
}

final hubWorkerActionViewModelProvider = StateNotifierProvider.autoDispose<
    HubWorkerActionViewModel, HubWorkerActionState>(
  (ref) => HubWorkerActionViewModel(ref),
);

Future<Result<void>> hubWorkerUpdateStatus(
  dynamic ds, {
  required String shipmentId,
  required ShipmentStatus newStatus,
  String? note,
}) async {
  try {
    await ds.updateStatus(
      shipmentId: shipmentId,
      newStatus: newStatus,
      note: note,
    );
    return const Success(null);
  } catch (e) {
    return Error(e.toString());
  }
}
