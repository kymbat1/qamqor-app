import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_code.dart';
import '../utils/auth_validators.dart';
import 'otp_delivery_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OtpDeliveryService _otpDeliveryService;

  static const int _otpTtlMinutes = 10;
  static const int _maxAttempts = 5;
  static const int _maxSendCount = 5;
  static const int _resendDelaySeconds = 60;

  AuthService({OtpDeliveryService? otpDeliveryService})
      : _otpDeliveryService =
            otpDeliveryService ?? OtpDeliveryServiceFactory.create();

  /// ===============================
  /// TOKEN (UID) STORAGE
  /// ===============================

  Future<void> saveToken(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uid', uid);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('uid');
  }

  Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('uid');
  }

  Future<String?> currentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      await saveToken(firebaseUser.uid);
      return firebaseUser.uid;
    }

    final savedUid = await getToken();
    if (savedUid != null && savedUid.isNotEmpty) {
      await deleteToken();
    }

    return null;
  }

  Future<Map<String, dynamic>?> currentUserData() async {
    final uid = await currentUser();
    if (uid == null || uid.isEmpty) {
      return null;
    }

    final userDoc = await _firestore.collection('users').doc(uid).get();
    return userDoc.data();
  }

  Future<String> currentUserRole() async {
    final userData = await currentUserData();
    return userData?['role'] ?? 'patient';
  }

  Future<void> updateCurrentUserName(String name) async {
    final uid = await currentUser();
    if (uid == null || uid.isEmpty) {
      throw Exception('user-not-found');
    }

    await _firestore.collection('users').doc(uid).update({
      'name': name.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCurrentUserProfile(Map<String, dynamic> data) async {
    final uid = await currentUser();
    if (uid == null || uid.isEmpty) {
      throw Exception('user-not-found');
    }

    final sanitized = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is String) {
        sanitized[key] = value.trim();
      } else {
        sanitized[key] = value;
      }
    });

    await _firestore.collection('users').doc(uid).set({
      ...sanitized,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ===============================
  /// REGISTER
  /// ===============================

  Future<void> register(String name, String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('user-null');
      }

      await saveToken(user.uid);

      await _firestore.collection('users').doc(user.uid).set({
        'name': name.trim(),
        'email': AuthValidators.normalizeEmail(email),
        'authProviders': FieldValue.arrayUnion(['password']),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    } catch (e) {
      throw Exception('unknown-error');
    }
  }

  /// ===============================
  /// LOGIN
  /// ===============================

  Future<void> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('user-null');
      }

      await saveToken(user.uid);
      await _firestore.collection('users').doc(user.uid).set({
        'email': AuthValidators.normalizeEmail(email),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    } catch (e) {
      throw Exception('unknown-error');
    }
  }

  /// ===============================
  /// OTP AUTH
  /// ===============================

  Future<OtpRequestResult> requestOtp({
    required OtpChannel channel,
    required String recipient,
  }) async {
    final normalizedRecipient = _normalizeRecipient(channel, recipient);
    _validateRecipient(channel, normalizedRecipient);

    final docRef = _otpDoc(channel, normalizedRecipient);
    final snapshot = await docRef.get();
    final now = DateTime.now();

    if (snapshot.exists) {
      final existing = AuthCode.fromJson(snapshot.data()!);
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
      sendCount: snapshot.exists
          ? AuthCode.fromJson(snapshot.data()!).sendCount + 1
          : 1,
      maxAttempts: _maxAttempts,
    );

    await docRef.set({
      ...authCode.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final debugCode = await _otpDeliveryService.sendCode(
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

    final docRef = _otpDoc(channel, normalizedRecipient);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      throw Exception('otp-not-found');
    }

    final authCode = AuthCode.fromJson(snapshot.data()!);

    if (authCode.isExpired) {
      await docRef.delete();
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
      await docRef.update({
        'attempts': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      throw Exception('otp-invalid');
    }

    final uid = await _findOrCreateOtpUser(
      channel: channel,
      recipient: normalizedRecipient,
      requestedRole: requestedRole,
    );

    await docRef.delete();
    await saveToken(uid);
    return uid;
  }

  /// ===============================
  /// LOGOUT
  /// ===============================

  Future<void> signOut() async {
    await _auth.signOut();
    await deleteToken();
  }

  DocumentReference<Map<String, dynamic>> _otpDoc(
    OtpChannel channel,
    String recipient,
  ) {
    final id = sha256.convert(utf8.encode('${channel.value}:$recipient'));
    return _firestore.collection('auth_codes').doc(id.toString());
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

  Future<String> _findOrCreateOtpUser({
    required OtpChannel channel,
    required String recipient,
    required String requestedRole,
  }) async {
    final field = channel == OtpChannel.email ? 'email' : 'phone';
    final provider = channel.value;
    final role = requestedRole == 'doctor' ? 'doctor' : 'patient';
    final users = await _firestore
        .collection('users')
        .where(field, isEqualTo: recipient)
        .limit(1)
        .get();

    if (users.docs.isNotEmpty) {
      final doc = users.docs.first;
      final existingRole = doc.data()['role'];
      await doc.reference.set({
        'authProviders': FieldValue.arrayUnion([provider]),
        'role': role == 'doctor' ? 'doctor' : existingRole ?? 'patient',
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (role == 'doctor') {
        await _ensureDoctorProfile(doc.id, doc.data(), field, recipient);
      }
      return doc.id;
    }

    final userRef = _firestore.collection('users').doc();
    await userRef.set({
      'name': 'Новый пользователь',
      field: recipient,
      'role': role,
      'authProviders': [provider],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    });

    if (role == 'doctor') {
      await _ensureDoctorProfile(userRef.id, {}, field, recipient);
    }

    return userRef.id;
  }

  Future<void> _ensureDoctorProfile(
    String uid,
    Map<String, dynamic> userData,
    String contactField,
    String contact,
  ) async {
    final profileRef = _firestore.collection('doctor_profiles').doc(uid);
    final profile = await profileRef.get();

    if (profile.exists) {
      return;
    }

    await profileRef.set({
      'userId': uid,
      'name': userData['name'] ?? 'Новый врач',
      contactField: contact,
      'specialty': '',
      'hospital': '',
      'university': '',
      'description': '',
      'consultationFee': 0,
      'yearsOfExperience': 0,
      'isOnline': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
