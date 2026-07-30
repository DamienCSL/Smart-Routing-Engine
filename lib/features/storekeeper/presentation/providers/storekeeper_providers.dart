import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/storekeeper_remote_datasource.dart';
import '../../data/repositories/storekeeper_repository_impl.dart';
import '../../domain/entities/storekeeper_task.dart';
import '../../domain/repositories/storekeeper_repository.dart';

final storekeeperRemoteDataSourceProvider =
    Provider<StorekeeperRemoteDataSource>((ref) {
  return StorekeeperRemoteDataSource(ref.watch(supabaseClientProvider));
});

final storekeeperRepositoryProvider = Provider<StorekeeperRepository>((ref) {
  return StorekeeperRepositoryImpl(
    ref.watch(storekeeperRemoteDataSourceProvider),
  );
});

final hubTasksProvider = StreamProvider<List<StorekeeperTask>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(storekeeperRepositoryProvider).watchHubTasks();
});

final storekeeperTaskDetailProvider =
    FutureProvider.family<StorekeeperTask?, String>((ref, shipmentId) async {
  final result = await ref
      .watch(storekeeperRepositoryProvider)
      .getTaskByShipmentId(shipmentId);
  return result.when(success: (t) => t, failure: (_) => null);
});
