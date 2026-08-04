import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/driver_api_providers.dart';
import '../../../../core/network/driver_api_session.dart';
import '../../data/mappers/customer_order_mapper.dart';
import '../../domain/entities/create_shipment_request.dart';
import '../../domain/entities/shipment.dart';
import '../providers/shipment_providers.dart';

class CreateShipmentState {
  const CreateShipmentState({
    this.isLoading = false,
    this.errorMessage,
    this.createdShipment,
  });

  final bool isLoading;
  final String? errorMessage;
  final Shipment? createdShipment;

  CreateShipmentState copyWith({
    bool? isLoading,
    String? errorMessage,
    Shipment? createdShipment,
    bool clearError = false,
    bool clearCreated = false,
  }) {
    return CreateShipmentState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdShipment:
          clearCreated ? null : (createdShipment ?? this.createdShipment),
    );
  }
}

class CreateShipmentViewModel extends StateNotifier<CreateShipmentState> {
  CreateShipmentViewModel(this._ref) : super(const CreateShipmentState());

  final Ref _ref;

  Future<Shipment?> submit(CreateShipmentRequest request) async {
    if (state.isLoading) return null;

    state = state.copyWith(isLoading: true, clearError: true, clearCreated: true);

    try {
      if (Env.useDriverApi && !Env.isSupabaseConfigured) {
        final api = _ref.read(driverApiClientProvider);
        final session = _ref.read(driverApiSessionProvider);
        final order = await api.createCustomerOrder(
          recipientName: request.packageDescription?.trim().isNotEmpty == true
              ? request.packageDescription!.trim()
              : request.destinationCity,
          address: request.destinationAddress,
          origin: CustomerOrderMapper.branchFromZone(request.originZone),
          dest: CustomerOrderMapper.branchFromZone(request.destinationZone),
          originZone: request.originZone,
          destinationZone: request.destinationZone,
          weight: request.weightKg,
          pieces: request.packageCount,
          senderName: session?.displayName,
        );
        final shipment = CustomerOrderMapper.fromApi(
          order,
          customerId: session?.uid ?? '',
        );
        state = state.copyWith(createdShipment: shipment);
        _ref.invalidate(customerShipmentsProvider);
        return shipment;
      }

      final result =
          await _ref.read(shipmentRepositoryProvider).createShipment(request);

      return result.when(
        success: (shipment) {
          state = state.copyWith(createdShipment: shipment);
          _ref.invalidate(customerShipmentsProvider);
          return shipment;
        },
        failure: (message) {
          state = state.copyWith(errorMessage: message);
          return null;
        },
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    } finally {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }
}

final createShipmentViewModelProvider =
    StateNotifierProvider.autoDispose<CreateShipmentViewModel, CreateShipmentState>(
  (ref) => CreateShipmentViewModel(ref),
);
