import 'package:shared_preferences/shared_preferences.dart';

import '../utils/auth_validators.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _apiClient;

  static const String _uidKey = 'uid';

  AuthService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

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

  Future<EmailRegistrationStartResult> startEmailRegistration({
    required String name,
    required String email,
    required String password,
    String role = 'client',
    String website = '',
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/register/start',
        auth: false,
        body: {
          'name': name.trim(),
          'email': AuthValidators.normalizeEmail(email),
          'password': password.trim(),
          'role': _normalizeBackendRole(role),
          'website': website,
        },
      );
      return EmailRegistrationStartResult.fromJson(response);
    } on ApiException catch (e) {
      throw Exception(_registrationCodeForApiError(e));
    } catch (_) {
      throw Exception('backend-unavailable');
    }
  }

  Future<EmailRegistrationStartResult> resendEmailRegistrationCode({
    required String email,
    String website = '',
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/register/resend',
        auth: false,
        body: {
          'email': AuthValidators.normalizeEmail(email),
          'website': website,
        },
      );
      return EmailRegistrationStartResult.fromJson(response);
    } on ApiException catch (e) {
      throw Exception(_registrationCodeForApiError(e));
    } catch (_) {
      throw Exception('backend-unavailable');
    }
  }

  Future<void> verifyEmailRegistration({
    required String email,
    required String code,
  }) async {
    try {
      final tokenResponse = await _apiClient.post(
        '/auth/register/verify',
        auth: false,
        body: {
          'email': AuthValidators.normalizeEmail(email),
          'code': code.trim(),
        },
      );
      await _saveBackendSession(tokenResponse);
    } on ApiException catch (e) {
      throw Exception(_registrationCodeForApiError(e));
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

  String _registrationCodeForApiError(ApiException error) {
    final message = error.message.toLowerCase();
    if (error.statusCode == 400 && message.contains('invalid verification')) {
      return 'verification-code-invalid';
    }
    if (error.statusCode == 400 && message.contains('registration rejected')) {
      return 'registration-rejected';
    }
    if (error.statusCode == 404) return 'verification-code-not-found';
    if (error.statusCode == 410 || message.contains('expired')) {
      return 'verification-code-expired';
    }
    if (error.statusCode == 409 || message.contains('already')) {
      return 'email-already-in-use';
    }
    if (error.statusCode == 429 && message.contains('resend')) {
      return 'otp-resend-too-soon';
    }
    if (error.statusCode == 429 && message.contains('wrong')) {
      return 'otp-too-many-attempts';
    }
    if (error.statusCode == 429) return 'otp-too-many-requests';
    if (message.contains('email')) return 'invalid-email';
    if (message.contains('password')) return 'weak-password';
    if (message.contains('smtp') || message.contains('send')) {
      return 'email-send-failed';
    }
    return _authCodeForApiError(error);
  }

}

class EmailRegistrationStartResult {
  final String email;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;
  final String message;
  final String? debugCode;

  const EmailRegistrationStartResult({
    required this.email,
    required this.expiresAt,
    required this.resendAvailableAt,
    required this.message,
    this.debugCode,
  });

  factory EmailRegistrationStartResult.fromJson(Map<String, dynamic> json) {
    return EmailRegistrationStartResult(
      email: json['email']?.toString() ?? '',
      expiresAt: DateTime.parse(json['expires_at'].toString()).toLocal(),
      resendAvailableAt:
          DateTime.parse(json['resend_available_at'].toString()).toLocal(),
      message: json['message']?.toString() ?? '',
      debugCode: json['debug_code']?.toString(),
    );
  }
}
