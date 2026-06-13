import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  static const String accessTokenKey = 'backend_access_token';
  static const String userIdKey = 'backend_user_id';

  final http.Client _httpClient;

  String get baseUrl {
    final configured = dotenv.env['BACKEND_API_URL']?.trim();
    if (configured != null && configured.isNotEmpty) {
      return _normalizeBaseUrl(configured);
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  Future<Map<String, dynamic>> get(
    String path, {
    bool auth = true,
  }) async {
    final response = await _httpClient
        .get(_uri(path), headers: await _headers(auth: auth))
        .timeout(const Duration(seconds: 25));
    return _decodeMap(response);
  }

  Future<List<dynamic>> getList(
    String path, {
    bool auth = true,
  }) async {
    final response = await _httpClient
        .get(_uri(path), headers: await _headers(auth: auth))
        .timeout(const Duration(seconds: 25));
    return _decodeList(response);
  }

  Future<Uint8List> getBytes(
    String path, {
    bool auth = true,
  }) async {
    final response = await _httpClient
        .get(_uri(path), headers: await _headers(auth: auth))
        .timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response), statusCode: response.statusCode);
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final response = await _httpClient
        .post(
          _uri(path),
          headers: await _headers(auth: auth),
          body: jsonEncode(body ?? {}),
        )
        .timeout(const Duration(seconds: 25));
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final response = await _httpClient
        .patch(
          _uri(path),
          headers: await _headers(auth: auth),
          body: jsonEncode(body ?? {}),
        )
        .timeout(const Duration(seconds: 25));
    return _decodeMap(response);
  }

  Future<void> delete(String path, {bool auth = true}) async {
    final response = await _httpClient
        .delete(_uri(path), headers: await _headers(auth: auth))
        .timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response), statusCode: response.statusCode);
    }
  }

  Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(accessTokenKey, token);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(accessTokenKey);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(accessTokenKey);
    await prefs.remove(userIdKey);
  }

  Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userIdKey, userId);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(userIdKey);
  }

  Uri _uri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }

  Future<Map<String, String>> _headers({required bool auth}) async {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth) {
      final token = await getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response), statusCode: response.statusCode);
    }
    if (response.bodyBytes.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const ApiException('Сервер вернул неожиданный формат ответа');
  }

  List<dynamic> _decodeList(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response), statusCode: response.statusCode);
    }
    if (response.bodyBytes.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is List) {
      return decoded;
    }
    throw const ApiException('Сервер вернул неожиданный формат списка');
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
        if (detail is List && detail.isNotEmpty) {
          return detail.first.toString();
        }
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Fallback below includes the HTTP status.
    }
    return 'Ошибка API ${response.statusCode}';
  }

  String _normalizeBaseUrl(String value) {
    var normalized = value;
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
