import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/driver_api_providers.dart';
import '../../../../core/network/driver_api_session.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../shipment/domain/entities/shipment.dart';
import '../../data/datasources/dispatcher_api_datasource.dart';
import '../../data/datasources/dispatcher_remote_datasource.dart';
import '../../data/repositories/dispatcher_repository_impl.dart';
import '../../domain/entities/dispatcher_profile.dart';
import '../../domain/entities/zone_driver_summary.dart';
import '../../domain/repositories/dispatcher_repository.dart';

final dispatcherApiDataSourceProvider = Provider<DispatcherApiDataSource>((ref) {
  return DispatcherApiDataSource(
    ref.watch(driverApiClientProvider),
    ref.watch(driverApiSessionProvider),
  );
});

final dispatcherRemoteDataSourceProvider =
    Provider<DispatcherRemoteDataSource?>((ref) {
  if (Env.useDriverApi || !Env.isSupabaseConfigured) return null;
  return DispatcherRemoteDataSource(ref.watch(supabaseClientProvider));
});

final dispatcherRepositoryProvider = Provider<DispatcherRepository?>((ref) {
  final remote = ref.watch(dispatcherRemoteDataSourceProvider);
  if (remote == null) return null;
  return DispatcherRepositoryImpl(remote);
});

final dispatcherProfileProvider = FutureProvider<DispatcherProfile?>((ref) async {
  ref.watch(authStateProvider);
  try {
    if (Env.useDriverApi) {
      return await ref.watch(dispatcherApiDataSourceProvider).getCurrentProfile();
    }
    final repo = ref.watch(dispatcherRepositoryProvider);
    if (repo == null) return null;
    final result = await repo.getCurrentProfile();
    return result.when(success: (p) => p, failure: (_) => null);
  } catch (_) {
    return null;
  }
});

final zoneShipmentsProvider = StreamProvider<List<Shipment>>((ref) {
  ref.watch(authStateProvider);
  if (Env.useDriverApi) {
    return ref.watch(dispatcherApiDataSourceProvider).watchUnassignedJobs();
  }
  final repo = ref.watch(dispatcherRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchZoneShipments();
});

final zoneDriversProvider = FutureProvider<List<ZoneDriverSummary>>((ref) async {
  ref.watch(authStateProvider);
  try {
    if (Env.useDriverApi) {
      return await ref.watch(dispatcherApiDataSourceProvider).getDrivers();
    }
    final repo = ref.watch(dispatcherRepositoryProvider);
    if (repo == null) return const [];
    final result = await repo.getZoneDrivers();
    return result.when(success: (d) => d, failure: (_) => const []);
  } catch (_) {
    return const [];
  }
});
