import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/driver_remote_datasource.dart';
import '../../data/repositories/driver_task_repository_impl.dart';
import '../../domain/entities/driver_task.dart';
import '../../domain/repositories/driver_task_repository.dart';

final driverRemoteDataSourceProvider = Provider<DriverRemoteDataSource>((ref) {
  return DriverRemoteDataSource(ref.watch(supabaseClientProvider));
});

final driverTaskRepositoryProvider = Provider<DriverTaskRepository>((ref) {
  return DriverTaskRepositoryImpl(ref.watch(driverRemoteDataSourceProvider));
});

final pickupTasksProvider = StreamProvider<List<DriverTask>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(driverTaskRepositoryProvider).watchPickupTasks();
});

final deliveryTasksProvider = StreamProvider<List<DriverTask>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(driverTaskRepositoryProvider).watchDeliveryTasks();
});

final driverTaskDetailProvider =
    FutureProvider.family<DriverTask?, String>((ref, shipmentId) async {
  final result = await ref
      .watch(driverTaskRepositoryProvider)
      .getTaskByShipmentId(shipmentId);
  return result.when(
    success: (task) => task,
    failure: (_) => null,
  );
});
