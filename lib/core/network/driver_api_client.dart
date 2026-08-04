import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../errors/exceptions.dart';
import '../utils/logger.dart';

/// HTTP client for IPOSB mobile API (MySQL master + bearer / demo auth).
class DriverApiClient {
  DriverApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? Env.driverApiUrl).replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;

  /// Set after login — opaque token, Firebase ID token, or `demo:<uid>`.
  String? accessToken;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$_baseUrl$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      throw const AuthException('Not authenticated to Driver API');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, String> get _publicHeaders => const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Map<String, String> get _dispatchHeaders => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Dispatch-Key': Env.dispatchApiKey,
      };

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final res = await _client
        .get(_uri(path, query), headers: _headers)
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  /// Public endpoints (customer tracking, labels) — no Bearer required.
  Future<Map<String, dynamic>> getPublicJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final res = await _client
        .get(_uri(path, query), headers: _publicHeaders)
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final res = await _client
        .post(
          _uri(path),
          headers: _headers,
          body: jsonEncode(body ?? {}),
        )
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<Map<String, dynamic>> postPublicJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final res = await _client
        .post(
          _uri(path),
          headers: _publicHeaders,
          body: jsonEncode(body ?? {}),
        )
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final res = await _client
        .patch(
          _uri(path),
          headers: _headers,
          body: jsonEncode(body ?? {}),
        )
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  /// Ops / demo endpoints protected by X-Dispatch-Key.
  Future<Map<String, dynamic>> postDispatchJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final res = await _client
        .post(
          _uri(path),
          headers: _dispatchHeaders,
          body: jsonEncode(body ?? {}),
        )
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getDispatchJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final res = await _client
        .get(_uri(path, query), headers: _dispatchHeaders)
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  /// Email/password login → stores bearer token.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final json = await postPublicJson('/auth/login', body: {
      'email': email.trim(),
      'password': password,
    });
    final token = json['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const AuthException('Login response missing token');
    }
    accessToken = token;
    return json;
  }

  /// Register customer, driver, or dispatcher → stores bearer token.
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String role = 'customer',
    String? phone,
    List<String>? preferredZones,
  }) async {
    final json = await postPublicJson('/auth/register', body: {
      'email': email.trim(),
      'password': password,
      'fullName': fullName.trim(),
      'role': role,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (preferredZones != null && preferredZones.isNotEmpty)
        'preferredZones': preferredZones,
    });
    final token = json['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const AuthException('Register response missing token');
    }
    accessToken = token;
    return json;
  }

  Future<void> logout() async {
    try {
      if (accessToken != null && !accessToken!.startsWith('demo:')) {
        await postJson('/auth/logout');
      }
    } catch (_) {
      // Best-effort revoke.
    } finally {
      accessToken = null;
    }
  }

  Future<List<Map<String, dynamic>>> listCustomerOrders({int limit = 50}) async {
    final json = await getJson('/customer/orders', query: {
      'limit': '$limit',
    });
    final list = json['orders'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> createCustomerOrder({
    required String recipientName,
    required String address,
    String origin = 'BKI',
    String dest = 'BKI',
    String? originZone,
    String? destinationZone,
    double weight = 1,
    int pieces = 1,
    String? phone,
    String? senderName,
  }) async {
    final json = await postJson('/customer/orders', body: {
      'recipientName': recipientName,
      'address': address,
      'origin': origin,
      'dest': dest,
      if (originZone != null && originZone.isNotEmpty) 'originZone': originZone,
      if (destinationZone != null && destinationZone.isNotEmpty)
        'destinationZone': destinationZone,
      'weight': weight,
      'pieces': pieces,
      if (phone != null) 'phone': phone,
      if (senderName != null) 'senderName': senderName,
    });
    final order = json['order'];
    if (order is Map<String, dynamic>) return order;
    if (order is Map) return Map<String, dynamic>.from(order);
    throw const ServerException('Create order response missing order');
  }

  Future<List<Map<String, dynamic>>> listNotifications() async {
    final json = await getJson('/notifications');
    final list = json['notifications'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json = {};
    if (res.body.isNotEmpty) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    }
    if (res.statusCode >= 400) {
      final msg = json['error']?.toString() ?? 'HTTP ${res.statusCode}';
      AppLogger.error('DriverApi error: $msg');
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw AuthException(msg);
      }
      if (res.statusCode == 404) {
        throw NotFoundException(msg);
      }
      throw ServerException(msg);
    }
    return json;
  }

  /// Local demo auth without Firebase / email login.
  void useDemoAuth([String? uid]) {
    accessToken = 'demo:${uid ?? Env.demoDriverUid}';
  }
}
