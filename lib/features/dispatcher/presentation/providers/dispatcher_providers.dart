import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../shipment/domain/entities/shipment.dart';
import '../../data/datasources/dispatcher_remote_datasource.dart';
import '../../data/repositories/dispatcher_repository_impl.dart';
import '../../domain/entities/dispatcher_profile.dart';
import '../../domain/entities/zone_driver_summary.dart';
import '../../domain/repositories/dispatcher_repository.dart';

final dispatcherRemoteDataSourceProvider =
    Provider<DispatcherRemoteDataSource>((ref) {
  return DispatcherRemoteDataSource(ref.watch(supabaseClientProvider));
});

final dispatcherRepositoryProvider = Provider<DispatcherRepository>((ref) {
  return DispatcherRepositoryImpl(ref.watch(dispatcherRemoteDataSourceProvider));
});

final dispatcherProfileProvider = FutureProvider<DispatcherProfile?>((ref) async {
  ref.watch(authStateProvider);
  final result = await ref.watch(dispatcherRepositoryProvider).getCurrentProfile();
  return result.when(success: (p) => p, failure: (_) => null);
});

final zoneShipmentsProvider = StreamProvider<List<Shipment>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(dispatcherRepositoryProvider).watchZoneShipments();
});

final zoneDriversProvider = FutureProvider<List<ZoneDriverSummary>>((ref) async {
  ref.watch(authStateProvider);
  final result = await ref.watch(dispatcherRepositoryProvider).getZoneDrivers();
  return result.when(success: (d) => d, failure: (_) => const []);
});
