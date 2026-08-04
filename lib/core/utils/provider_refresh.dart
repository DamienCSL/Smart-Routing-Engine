import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Await a fresh provider value so [RefreshIndicator] / refresh buttons
/// actually wait until updated data is on screen.
///
/// Pass `someProvider.future` (FutureProvider / StreamProvider).
Future<T> refreshAndWait<T>(
  WidgetRef ref,
  Refreshable<Future<T>> providerFuture,
) {
  return ref.refresh(providerFuture);
}

/// Same helper for use inside ViewModels / notifiers that only have [Ref].
Future<T> refreshAndWaitRef<T>(
  Ref ref,
  Refreshable<Future<T>> providerFuture,
) {
  return ref.refresh(providerFuture);
}
