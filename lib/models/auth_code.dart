import 'package:cloud_firestore/cloud_firestore.dart';

enum OtpChannel {
  email,
  whatsapp,
}

extension OtpChannelX on OtpChannel {
  String get value {
    switch (this) {
      case OtpChannel.email:
        return 'email';
      case OtpChannel.whatsapp:
        return 'whatsapp';
    }
  }

  String get title {
    switch (this) {
      case OtpChannel.email:
        return 'Email';
      case OtpChannel.whatsapp:
        return 'WhatsApp';
    }
  }
}

class AuthCode {
  final String channel;
  final String recipient;
  final String codeHash;
  final String salt;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;
  final int attempts;
  final int sendCount;
  final int maxAttempts;

  const AuthCode({
    required this.channel,
    required this.recipient,
    required this.codeHash,
    required this.salt,
    required this.expiresAt,
    required this.resendAvailableAt,
    required this.attempts,
    required this.sendCount,
    required this.maxAttempts,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get canResend => DateTime.now().isAfter(resendAvailableAt);
  bool get hasAttemptsLeft => attempts < maxAttempts;

  factory AuthCode.fromJson(Map<String, dynamic> json) {
    return AuthCode(
      channel: json['channel'] ?? '',
      recipient: json['recipient'] ?? '',
      codeHash: json['codeHash'] ?? '',
      salt: json['salt'] ?? '',
      expiresAt: _readDate(json['expiresAt']),
      resendAvailableAt: _readDate(json['resendAvailableAt']),
      attempts: json['attempts'] ?? 0,
      sendCount: json['sendCount'] ?? 0,
      maxAttempts: json['maxAttempts'] ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel': channel,
      'recipient': recipient,
      'codeHash': codeHash,
      'salt': salt,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'resendAvailableAt': Timestamp.fromDate(resendAvailableAt),
      'attempts': attempts,
      'sendCount': sendCount,
      'maxAttempts': maxAttempts,
    };
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class OtpRequestResult {
  final String recipient;
  final OtpChannel channel;
  final DateTime expiresAt;
  final String? debugCode;

  const OtpRequestResult({
    required this.recipient,
    required this.channel,
    required this.expiresAt,
    this.debugCode,
  });
}
