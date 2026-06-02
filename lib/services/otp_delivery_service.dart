import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/auth_code.dart';

abstract class OtpDeliveryService {
  Future<String?> sendCode({
    required OtpChannel channel,
    required String recipient,
    required String code,
  });
}

class DebugOtpDeliveryService implements OtpDeliveryService {
  @override
  Future<String?> sendCode({
    required OtpChannel channel,
    required String recipient,
    required String code,
  }) async {
    debugPrint('OTP ${channel.value} code for $recipient: $code');
    return code;
  }
}

class HttpOtpDeliveryService implements OtpDeliveryService {
  final http.Client _client;
  final String baseUrl;
  final String? apiKey;

  HttpOtpDeliveryService({
    http.Client? client,
    required this.baseUrl,
    this.apiKey,
  }) : _client = client ?? http.Client();

  @override
  Future<String?> sendCode({
    required OtpChannel channel,
    required String recipient,
    required String code,
  }) async {
    final uri = Uri.parse('$baseUrl/otp/send');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey!.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'channel': channel.value,
        'recipient': recipient,
        'code': code,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('otp-delivery-failed');
    }

    return null;
  }
}

class OtpDeliveryServiceFactory {
  static OtpDeliveryService create() {
    final mode = dotenv.env['OTP_DELIVERY_MODE'] ?? 'debug';
    if (mode == 'http') {
      final baseUrl = dotenv.env['OTP_API_BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        throw Exception('otp-api-base-url-missing');
      }

      return HttpOtpDeliveryService(
        baseUrl: baseUrl,
        apiKey: dotenv.env['OTP_API_KEY'],
      );
    }

    return DebugOtpDeliveryService();
  }
}
