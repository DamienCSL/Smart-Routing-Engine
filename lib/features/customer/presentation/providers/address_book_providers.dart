import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/driver_api_providers.dart';
import '../../domain/entities/saved_address.dart';

final customerAddressBookProvider =
    FutureProvider.family<List<SavedAddress>, AddressBookKind?>((ref, kind) async {
  if (!Env.useDriverApi || Env.isSupabaseConfigured) {
    return const [];
  }
  final api = ref.watch(driverApiClientProvider);
  final rows = await api.listCustomerAddresses(
    kind: kind?.apiValue == 'both' ? null : kind?.apiValue,
  );
  return rows.map(SavedAddress.fromJson).toList();
});
