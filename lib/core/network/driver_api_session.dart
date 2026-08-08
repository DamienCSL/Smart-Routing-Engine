import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    this.phone,
    this.userId = 0,
    this.firebaseUid,
    this.driverId,
    this.dispatcherId,
    this.custAcNo,
    this.preferredZones = const [],
    this.isActive = true,
    this.createdAt,
  });

  final String uid;
  final String displayName;
  final String token;
  final UserRole role;
  final String email;
  final String? phone;
  final int userId;
  final String? firebaseUid;
  final int? driverId;
  final int? dispatcherId;
  final String? custAcNo;
  final List<String> preferredZones;
  final bool isActive;
  final DateTime? createdAt;

  DriverApiSession copyWith({
    List<String>? preferredZones,
    String? displayName,
    String? phone,
    bool? isActive,
    DateTime? createdAt,
    int? driverId,
    int? dispatcherId,
    String? custAcNo,
  }) {
    return DriverApiSession(
      uid: uid,
      displayName: displayName ?? this.displayName,
      token: token,
      role: role,
      email: email,
      phone: phone ?? this.phone,
      userId: userId,
      firebaseUid: firebaseUid,
      driverId: driverId ?? this.driverId,
      dispatcherId: dispatcherId ?? this.dispatcherId,
      custAcNo: custAcNo ?? this.custAcNo,
      preferredZones: preferredZones ?? this.preferredZones,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DriverApiSessionNotifier extends StateNotifier<DriverApiSession?> {
  DriverApiSessionNotifier(this._api, this._storage) : super(null) {
    _restore();
  }

  final DriverApiClient _api;
  final FlutterSecureStorage _storage;
  static const _tokenKey = 'driver_api_access_token';

  Future<void> _restore() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.isEmpty || token.startsWith('demo:')) return;
      _api.accessToken = token;
      final json = await _api.getJson('/auth/me');
      final user = json['user'];
      final map = user is Map<String, dynamic>
          ? user
          : user is Map
          ? Map<String, dynamic>.from(user)
          : <String, dynamic>{};
      if (map.isEmpty) throw StateError('Session user missing');
      state = _sessionFromUserMap(map, token: token);
    } catch (_) {
      _api.accessToken = null;
      await _storage.delete(key: _tokenKey);
    }
  }

  Future<void> _persistToken() async {
    final token = _api.accessToken;
    if (token != null && token.isNotEmpty && !token.startsWith('demo:')) {
      await _storage.write(key: _tokenKey, value: token);
    }
  }

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
    await _persistToken();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
    List<String>? preferredZones,
  }) async {
    final apiRole = role == UserRole.hubWorker || role == UserRole.driver
        ? 'driver'
        : role == UserRole.dispatcher
        ? 'dispatcher'
        : 'customer';
    final json = await _api.register(
      email: email,
      password: password,
      fullName: fullName,
      role: apiRole,
      phone: phone,
      preferredZones: preferredZones,
    );
    state = _sessionFromAuthJson(json);
    await _persistToken();
  }

  /// Refresh identity from GET /auth/me.
  Future<void> refreshMe() async {
    final session = state;
    if (session == null) return;
    final json = await _api.getJson('/auth/me');
    final user = json['user'];
    final map = user is Map<String, dynamic>
        ? user
        : user is Map
        ? Map<String, dynamic>.from(user)
        : <String, dynamic>{};
    if (map.isEmpty) return;
    state = _sessionFromUserMap(map, token: session.token);
  }

  /// Update name/phone via PATCH /auth/me (all roles).
  Future<void> updateProfile({required String fullName, String? phone}) async {
    final session = state;
    if (session == null) return;
    final json = await _api.patchJson(
      '/auth/me',
      body: {
        'fullName': fullName.trim(),
        'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      },
    );
    final user = json['user'];
    final map = user is Map<String, dynamic>
        ? user
        : user is Map
        ? Map<String, dynamic>.from(user)
        : <String, dynamic>{};
    if (map.isNotEmpty) {
      state = _sessionFromUserMap(map, token: session.token);
    } else {
      state = session.copyWith(
        displayName: fullName.trim(),
        phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      );
    }
  }

  Future<void> updatePreferredZones(List<String> zones) async {
    final session = state;
    if (session == null) return;
    if (session.role == UserRole.dispatcher) {
      await _api.patchJson('/dispatcher/me', body: {'preferredZones': zones});
    } else if (session.role == UserRole.hubWorker ||
        session.role == UserRole.driver) {
      await _api.patchJson('/driver/me', body: {'preferredZones': zones});
    } else {
      return;
    }
    state = session.copyWith(preferredZones: zones);
  }

  Future<void> signInWithFirebaseToken({
    required String uid,
    required String idToken,
    String? displayName,
  }) async {
    final json = await _api.postPublicJson(
      '/auth/firebase',
      body: {'firebaseUid': uid, 'idToken': idToken},
    );
    final token = json['token']?.toString();
    if (token != null && token.isNotEmpty) {
      _api.accessToken = token;
      state = _sessionFromAuthJson(json);
      await _persistToken();
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
    await _storage.delete(key: _tokenKey);
    state = null;
  }

  DriverApiSession _sessionFromAuthJson(Map<String, dynamic> json) {
    final user = json['user'];
    final map = user is Map<String, dynamic>
        ? user
        : user is Map
        ? Map<String, dynamic>.from(user)
        : <String, dynamic>{};
    return _sessionFromUserMap(map, token: _api.accessToken!);
  }

  DriverApiSession _sessionFromUserMap(
    Map<String, dynamic> map, {
    required String token,
  }) {
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
      token: token,
      role: role,
      email: email,
      phone: map['phone']?.toString(),
      userId: int.tryParse('${map['id'] ?? 0}') ?? 0,
      firebaseUid: firebaseUid,
      driverId: map['driverId'] == null
          ? null
          : int.tryParse('${map['driverId']}'),
      dispatcherId: map['dispatcherId'] == null
          ? null
          : int.tryParse('${map['dispatcherId']}'),
      custAcNo: map['custAcNo']?.toString(),
      preferredZones: _parseZones(map['preferredZones']),
      isActive: map['isActive'] != false && map['isActive'] != 0,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  List<String> _parseZones(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }
}

final driverApiSessionProvider =
    StateNotifierProvider<DriverApiSessionNotifier, DriverApiSession?>((ref) {
      return DriverApiSessionNotifier(
        ref.watch(driverApiClientProvider),
        const FlutterSecureStorage(),
      );
    });

/// Listenable bridge so GoRouter refreshes on driver API session changes.
class DriverApiSessionListenable extends ChangeNotifier {
  DriverApiSessionListenable(this._ref) {
    _ref.listen(driverApiSessionProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}

final driverApiSessionListenableProvider = Provider<DriverApiSessionListenable>(
  (ref) {
    return DriverApiSessionListenable(ref);
  },
);
