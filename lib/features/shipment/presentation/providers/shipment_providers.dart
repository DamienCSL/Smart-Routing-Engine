import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/driver_api_providers.dart';
import '../../../../core/network/driver_api_session.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../assignment_engine/data/datasources/assignment_remote_datasource.dart';
import '../../../assignment_engine/data/routing_assignment_engine.dart';
import '../../../assignment_engine/domain/assignment_engine.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/shipment_remote_datasource.dart';
import '../../data/mappers/customer_order_mapper.dart';
import '../../data/repositories/shipment_repository_impl.dart';
import '../../domain/entities/shipment.dart';
import '../../domain/entities/shipment_history_entry.dart';
import '../../domain/repositories/shipment_repository.dart';

final assignmentRemoteDataSourceProvider =
    Provider<AssignmentRemoteDataSource>((ref) {
  return AssignmentRemoteDataSource(ref.watch(supabaseClientProvider));
});

final assignmentEngineProvider = Provider<AssignmentEngine>((ref) {
  return RoutingAssignmentEngine(
    ref.watch(assignmentRemoteDataSourceProvider),
  );
});

final shipmentRemoteDataSourceProvider =
    Provider<ShipmentRemoteDataSource>((ref) {
  return ShipmentRemoteDataSource(ref.watch(supabaseClientProvider));
});

final shipmentRepositoryProvider = Provider<ShipmentRepository>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return ShipmentRepositoryImpl(
    dataSource: ref.watch(shipmentRemoteDataSourceProvider),
    assignmentEngine: ref.watch(assignmentEngineProvider),
    currentUserId: () => auth.currentUserId ?? '',
  );
});

/// List of the signed-in customer's shipments.
final customerShipmentsProvider = StreamProvider<List<Shipment>>((ref) {
  ref.watch(authStateProvider);

  if (Env.useDriverApi && !Env.isSupabaseConfigured) {
    final session = ref.watch(driverApiSessionProvider);
    if (session == null) {
      return Stream.value(const <Shipment>[]);
    }
    final api = ref.watch(driverApiClientProvider);
    return Stream.fromFuture(() async {
      final orders = await api.listCustomerOrders();
      return orders
          .map((o) => CustomerOrderMapper.fromApi(o, customerId: session.uid))
          .toList();
    }());
  }

  final auth = ref.watch(authRepositoryProvider);
  final userId = auth.currentUserId;
  if (userId == null) {
    return Stream.value(const <Shipment>[]);
  }

  return ref.watch(shipmentRepositoryProvider).watchCustomerShipments(userId);
});

final shipmentDetailProvider =
    FutureProvider.family<Shipment?, String>((ref, shipmentId) async {
  if (Env.useDriverApi && !Env.isSupabaseConfigured) {
    final api = ref.watch(driverApiClientProvider);
    final session = ref.watch(driverApiSessionProvider);
    try {
      final json = await api.getJson('/customer/orders/$shipmentId');
      final order = json['order'];
      if (order is Map) {
        return CustomerOrderMapper.fromApi(
          Map<String, dynamic>.from(order),
          customerId: session?.uid ?? '',
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  final result =
      await ref.watch(shipmentRepositoryProvider).getShipmentById(shipmentId);
  return result.when(
    success: (shipment) => shipment,
    failure: (_) => null,
  );
});

final shipmentHistoryProvider =
    FutureProvider.family<List<ShipmentHistoryEntry>, String>(
        (ref, shipmentId) async {
  if (Env.useDriverApi && !Env.isSupabaseConfigured) {
    final api = ref.watch(driverApiClientProvider);
    try {
      final json = await api.getPublicJson('/tracking/$shipmentId');
      final timeline = json['timeline'];
      if (timeline is! List) return const [];
      final entries = <ShipmentHistoryEntry>[];
      for (var i = 0; i < timeline.length; i++) {
        final raw = timeline[i];
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final code = (row['statusCode'] ?? '').toString();
        final label = (row['customerLabel'] ?? code).toString();
        final note = (row['note'] ?? '').toString();
        entries.add(
          ShipmentHistoryEntry(
            id: '$shipmentId-$i',
            shipmentId: shipmentId,
            status: CustomerOrderMapper.statusFromCnCode(code),
            description: note.isNotEmpty ? '$label — $note' : label,
            location: row['location']?.toString(),
            performedBy: row['by']?.toString(),
            createdAt: DateTime.tryParse((row['at'] ?? '').toString()) ??
                DateTime.now(),
          ),
        );
      }
      return entries;
    } catch (_) {
      return const [];
    }
  }
  final result = await ref
      .watch(shipmentRepositoryProvider)
      .getShipmentHistory(shipmentId);
  return result.when(
    success: (entries) => entries,
    failure: (_) => const [],
  );
});
