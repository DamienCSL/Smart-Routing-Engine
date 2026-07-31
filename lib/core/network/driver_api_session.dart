import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/enums/user_role.dart';
import '../config/env.dart';
import 'driver_api_client.dart';
import 'driver_api_providers.dart';

/// In-memory session for Driver API mode (opaque token, Firebase, or demo).
class DriverApiSession {
  const DriverApiSession({
    required this.uid,
    required this.displayName,
    required this.token,
    required this.role,
    this.email = '',
    this.userId = 0,
    this.firebaseUid,
    this.driverId,
    this.dispatcherId,
    this.custAcNo,
  });

  final String uid;
  final String displayName;
  final String token;
  final UserRole role;
  final String email;
  final int userId;
  final String? firebaseUid;
  final int? driverId;
  final int? dispatcherId;
  final String? custAcNo;
}

class DriverApiSessionNotifier extends StateNotifier<DriverApiSession?> {
  DriverApiSessionNotifier(this._api) : super(null);

  final DriverApiClient _api;

  Future<void> signInDemo({String? uid, String? displayName}) async {
    final id = uid ?? Env.demoDriverUid;
    _api.useDemoAuth(id);
    state = DriverApiSession(
      uid: id,
      displayName: displayName ?? 'IPOSB Driver',
      token: _api.accessToken!,
      role: UserRole.hubWorker,
      email: '$id@iposb.driver',
      firebaseUid: id,
    );
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final json = await _api.login(email: email, password: password);
    state = _sessionFromAuthJson(json);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
  }) async {
    final apiRole = role == UserRole.hubWorker || role == UserRole.driver
        ? 'driver'
        : 'customer';
    final json = await _api.register(
      email: email,
      password: password,
      fullName: fullName,
      role: apiRole,
      phone: phone,
    );
    state = _sessionFromAuthJson(json);
  }

  Future<void> signInWithFirebaseToken({
    required String uid,
    required String idToken,
    String? displayName,
  }) async {
    final json = await _api.postPublicJson('/auth/firebase', body: {
      'firebaseUid': uid,
      'idToken': idToken,
    });
    final token = json['token']?.toString();
    if (token != null && token.isNotEmpty) {
      _api.accessToken = token;
      state = _sessionFromAuthJson(json);
      return;
    }
    _api.accessToken = idToken;
    state = DriverApiSession(
      uid: uid,
      displayName: displayName ?? 'IPOSB Driver',
      token: idToken,
      role: UserRole.hubWorker,
      firebaseUid: uid,
    );
  }

  Future<void> signOut() async {
    await _api.logout();
    state = null;
  }

  DriverApiSession _sessionFromAuthJson(Map<String, dynamic> json) {
    final user = json['user'];
    final map = user is Map<String, dynamic>
        ? user
        : user is Map
            ? Map<String, dynamic>.from(user)
            : <String, dynamic>{};
    final roleRaw = (map['role'] ?? 'customer').toString();
    final role = roleRaw == 'driver'
        ? UserRole.hubWorker
        : UserRole.fromValue(roleRaw);
    final email = (map['email'] ?? '').toString();
    final firebaseUid = map['firebaseUid']?.toString();
    final uid = firebaseUid?.isNotEmpty == true
        ? firebaseUid!
        : (map['id']?.toString() ?? email);
    return DriverApiSession(
      uid: uid,
      displayName: (map['fullName'] ?? email).toString(),
      token: _api.accessToken!,
      role: role,
      email: email,
      userId: int.tryParse('${map['id'] ?? 0}') ?? 0,
      firebaseUid: firebaseUid,
      driverId: map['driverId'] == null
          ? null
          : int.tryParse('${map['driverId']}'),
      dispatcherId: map['dispatcherId'] == null
          ? null
          : int.tryParse('${map['dispatcherId']}'),
      custAcNo: map['custAcNo']?.toString(),
    );
  }
}

final driverApiSessionProvider =
    StateNotifierProvider<DriverApiSessionNotifier, DriverApiSession?>((ref) {
  return DriverApiSessionNotifier(ref.watch(driverApiClientProvider));
});

/// Listenable bridge so GoRouter refreshes on driver API session changes.
class DriverApiSessionListenable extends ChangeNotifier {
  DriverApiSessionListenable(this._ref) {
    _ref.listen(driverApiSessionProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}

final driverApiSessionListenableProvider =
    Provider<DriverApiSessionListenable>((ref) {
  return DriverApiSessionListenable(ref);
});
