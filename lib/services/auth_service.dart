import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_code.dart';
import '../utils/auth_validators.dart';
import 'api_client.dart';
import 'otp_delivery_service.dart';

class AuthService {
  final OtpDeliveryService? _otpDeliveryService;
  final ApiClient _apiClient;

  static const int _otpTtlMinutes = 10;
  static const int _maxAttempts = 5;
  static const int _maxSendCount = 5;
  static const int _resendDelaySeconds = 60;
  static const String _uidKey = 'uid';
  static const String _otpPrefix = 'otp_code_';

  AuthService({
    OtpDeliveryService? otpDeliveryService,
    ApiClient? apiClient,
  })  : _otpDeliveryService = otpDeliveryService,
        _apiClient = apiClient ?? ApiClient();

  Future<void> saveToken(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uidKey, uid);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_uidKey);
  }

  Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uidKey);
    await _apiClient.clearSession();
  }

  Future<String?> currentUser() async {
    final backendUserId = await _apiClient.getUserId();
    final backendToken = await _apiClient.getAccessToken();
    if (backendUserId != null &&
        backendUserId.isNotEmpty &&
        backendToken != null &&
        backendToken.isNotEmpty) {
      return backendUserId;
    }

    if (backendToken != null && backendToken.isNotEmpty) {
      final userData = await currentUserData();
      final id = userData?['id']?.toString();
      if (id != null && id.isNotEmpty) {
        await saveToken(id);
        await _apiClient.saveUserId(id);
        return id;
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> currentUserData() async {
    final backendToken = await _apiClient.getAccessToken();
    if (backendToken == null || backendToken.isEmpty) {
      return null;
    }

    try {
      final data = await _apiClient.get('/auth/me');
      final id = data['id']?.toString();
      if (id != null && id.isNotEmpty) {
        await saveToken(id);
        await _apiClient.saveUserId(id);
      }
      return data;
    } catch (_) {
      await _apiClient.clearSession();
      return null;
    }
  }

  Future<String> currentUserRole() async {
    final userData = await currentUserData();
    final role = userData?['role']?.toString();
    if (role == 'patient') return 'client';
    return role ?? 'client';
  }

  Future<void> updateCurrentUserName(String name) async {
    await _apiClient.patch('/users/me', body: {'name': name.trim()});
  }

  Future<void> updateCurrentUserProfile(Map<String, dynamic> data) async {
    final payload = <String, dynamic>{};
    if (data['name'] != null) payload['name'] = data['name'].toString().trim();
    if (data['phone'] != null) payload['phone'] = data['phone'].toString().trim();
    if (payload.isNotEmpty) {
      await _apiClient.patch('/users/me', body: payload);
    }
  }

  Future<void> register(
    String name,
    String email,
    String password, {
    String role = 'client',
  }) async {
    final normalizedRole = _normalizeBackendRole(role);
    try {
      final tokenResponse = await _apiClient.post(
        '/auth/register',
        auth: false,
        body: {
          'name': name.trim(),
          'email': AuthValidators.normalizeEmail(email),
          'password': password.trim(),
          'role': normalizedRole,
        },
      );
      await _saveBackendSession(tokenResponse);
    } on ApiException catch (e) {
      throw Exception(_authCodeForApiError(e));
    } catch (_) {
      throw Exception('backend-unavailable');
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      final tokenResponse = await _apiClient.post(
        '/auth/login',
        auth: false,
        body: {
          'email': AuthValidators.normalizeEmail(email),
          'password': password.trim(),
        },
      );
      await _saveBackendSession(tokenResponse);
    } on ApiException catch (e) {
      throw Exception(_authCodeForApiError(e));
    } catch (_) {
      throw Exception('backend-unavailable');
    }
  }

  Future<OtpRequestResult> requestOtp({
    required OtpChannel channel,
    required String recipient,
  }) async {
    final normalizedRecipient = _normalizeRecipient(channel, recipient);
    _validateRecipient(channel, normalizedRecipient);

    final prefs = await SharedPreferences.getInstance();
    final key = _otpStorageKey(channel, normalizedRecipient);
    final existingRaw = prefs.getString(key);
    final now = DateTime.now();
    AuthCode? existing;
    if (existingRaw != null && existingRaw.isNotEmpty) {
      existing = AuthCode.fromJson(jsonDecode(existingRaw));
      if (!existing.isExpired && !existing.canResend) {
        throw Exception('otp-resend-too-soon');
      }
      if (!existing.isExpired && existing.sendCount >= _maxSendCount) {
        throw Exception('otp-too-many-requests');
      }
    }

    final code = _generateCode();
    final salt = _generateSalt();
    final expiresAt = now.add(const Duration(minutes: _otpTtlMinutes));
    final authCode = AuthCode(
      channel: channel.value,
      recipient: normalizedRecipient,
      codeHash: _hashCode(
        code: code,
        salt: salt,
        recipient: normalizedRecipient,
      ),
      salt: salt,
      expiresAt: expiresAt,
      resendAvailableAt:
          now.add(const Duration(seconds: _resendDelaySeconds)),
      attempts: 0,
      sendCount: existing == null || existing.isExpired
          ? 1
          : existing.sendCount + 1,
      maxAttempts: _maxAttempts,
    );

    await prefs.setString(key, jsonEncode(authCode.toJson()));

    final otpDeliveryService =
        _otpDeliveryService ?? OtpDeliveryServiceFactory.create();
    final debugCode = await otpDeliveryService.sendCode(
      channel: channel,
      recipient: normalizedRecipient,
      code: code,
    );

    return OtpRequestResult(
      recipient: normalizedRecipient,
      channel: channel,
      expiresAt: expiresAt,
      debugCode: debugCode,
    );
  }

  Future<String> verifyOtp({
    required OtpChannel channel,
    required String recipient,
    required String code,
    String requestedRole = 'patient',
  }) async {
    final normalizedRecipient = _normalizeRecipient(channel, recipient);
    _validateRecipient(channel, normalizedRecipient);

    if (!AuthValidators.isValidCode(code)) {
      throw Exception('otp-invalid-format');
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _otpStorageKey(channel, normalizedRecipient);
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      throw Exception('otp-not-found');
    }

    final authCode = AuthCode.fromJson(jsonDecode(raw));
    if (authCode.isExpired) {
      await prefs.remove(key);
      throw Exception('otp-expired');
    }

    if (!authCode.hasAttemptsLeft) {
      throw Exception('otp-too-many-attempts');
    }

    final incomingHash = _hashCode(
      code: code.trim(),
      salt: authCode.salt,
      recipient: normalizedRecipient,
    );

    if (incomingHash != authCode.codeHash) {
      final updated = authCode.copyWith(attempts: authCode.attempts + 1);
      await prefs.setString(key, jsonEncode(updated.toJson()));
      throw Exception('otp-invalid');
    }

    final tokenResponse = await _apiClient.post(
      '/auth/passwordless-login',
      auth: false,
      body: {
        if (channel == OtpChannel.email) 'email': normalizedRecipient,
        if (channel == OtpChannel.whatsapp) 'phone': normalizedRecipient,
        'role': _normalizeBackendRole(requestedRole),
      },
    );
    await prefs.remove(key);
    await _saveBackendSession(tokenResponse);
    final uid = await currentUser();
    if (uid == null || uid.isEmpty) {
      throw Exception('missing-user-id');
    }
    return uid;
  }

  Future<void> signOut() async {
    await deleteToken();
  }

  Future<void> _saveBackendSession(Map<String, dynamic> tokenResponse) async {
    final token = tokenResponse['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('missing-access-token');
    }
    await _apiClient.saveAccessToken(token);
    final userData = await _apiClient.get('/auth/me');
    final id = userData['id']?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('missing-user-id');
    }
    await saveToken(id);
    await _apiClient.saveUserId(id);
  }

  String _normalizeBackendRole(String role) {
    if (role == 'patient') return 'client';
    if (role == 'doctor') return 'doctor';
    if (role == 'admin') return 'admin';
    return 'client';
  }

  String _authCodeForApiError(ApiException error) {
    final message = error.message.toLowerCase();
    if (error.statusCode == 401) return 'invalid-credential';
    if (error.statusCode == 409 || message.contains('already')) {
      return 'email-already-in-use';
    }
    if (message.contains('email')) return 'invalid-email';
    if (message.contains('password')) return 'weak-password';
    if (message.contains('connection') ||
        message.contains('xmlhttprequest') ||
        message.contains('failed')) {
      return 'backend-unavailable';
    }
    return error.message;
  }

  String _otpStorageKey(OtpChannel channel, String recipient) {
    final id = sha256.convert(utf8.encode('${channel.value}:$recipient'));
    return '$_otpPrefix$id';
  }

  String _normalizeRecipient(OtpChannel channel, String recipient) {
    switch (channel) {
      case OtpChannel.email:
        return AuthValidators.normalizeEmail(recipient);
      case OtpChannel.whatsapp:
        return AuthValidators.normalizePhone(recipient);
    }
  }

  void _validateRecipient(OtpChannel channel, String recipient) {
    switch (channel) {
      case OtpChannel.email:
        if (!AuthValidators.isValidEmail(recipient)) {
          throw Exception('invalid-email');
        }
        return;
      case OtpChannel.whatsapp:
        if (!AuthValidators.isValidPhone(recipient)) {
          throw Exception('invalid-phone');
        }
        return;
    }
  }

  String _generateCode() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  String _hashCode({
    required String code,
    required String salt,
    required String recipient,
  }) {
    return sha256
        .convert(utf8.encode('$recipient:$code:$salt'))
        .toString();
  }
}
