import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/drop_point_remote_datasource.dart';
import '../../data/repositories/drop_point_repository_impl.dart';
import '../../domain/entities/drop_point_task.dart';
import '../../domain/repositories/drop_point_repository.dart';

final dropPointRemoteDataSourceProvider =
    Provider<DropPointRemoteDataSource>((ref) {
  return DropPointRemoteDataSource(ref.watch(supabaseClientProvider));
});

final dropPointRepositoryProvider = Provider<DropPointRepository>((ref) {
  return DropPointRepositoryImpl(ref.watch(dropPointRemoteDataSourceProvider));
});

final originIntakeTasksProvider = StreamProvider<List<DropPointTask>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(dropPointRepositoryProvider).watchOriginIntakeTasks();
});

final destinationIntakeTasksProvider =
    StreamProvider<List<DropPointTask>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(dropPointRepositoryProvider).watchDestinationIntakeTasks();
});

final dropPointTaskDetailProvider =
    FutureProvider.family<DropPointTask?, String>((ref, shipmentId) async {
  final result = await ref
      .watch(dropPointRepositoryProvider)
      .getTaskByShipmentId(shipmentId);
  return result.when(success: (t) => t, failure: (_) => null);
});
