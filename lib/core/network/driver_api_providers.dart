import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'driver_api_client.dart';

final driverApiClientProvider = Provider<DriverApiClient>((ref) {
  final client = DriverApiClient();
  // Demo token until Firebase Auth is wired in production builds.
  if (Env.useDriverApi) {
    client.useDemoAuth();
  }
  return client;
});
