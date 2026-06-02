import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment.dart';
import '../models/doctor.dart';
import 'auth_service.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;

  AppointmentService({AuthService? authService})
      : _authService = authService ?? AuthService();

  Future<String> createAppointment({
    required Doctor doctor,
    required DateTime dateTime,
  }) async {
    final patientId = await _authService.currentUser();
    if (patientId == null || patientId.isEmpty) {
      throw Exception('user-not-found');
    }

    final userData = await _authService.currentUserData() ?? {};
    final patientName = userData['name'] ?? 'Пациент';
    final patientContact = userData['email'] ?? userData['phone'] ?? '';
    final doctorId = doctor.id.isNotEmpty ? doctor.id : _fallbackDoctorId(doctor.name);
    final appointmentRef = _firestore.collection('appointments').doc();
    final chatId = _chatId(patientId, doctorId);

    await appointmentRef.set({
      'patientId': patientId,
      'patientName': patientName,
      'patientContact': patientContact,
      'doctorId': doctorId,
      'doctorName': doctor.name,
      'doctorSpecialty': doctor.specialty,
      'dateTime': Timestamp.fromDate(dateTime),
      'status': 'scheduled',
      'chatId': chatId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('chats').doc(chatId).set({
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctor.name,
      'appointmentId': appointmentRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return appointmentRef.id;
  }

  Stream<List<Appointment>> watchDoctorAppointments(String doctorId) {
    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => Appointment.fromJson(doc.data(), doc.id))
          .toList();
      items.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return items;
    });
  }

  Stream<List<Appointment>> watchPatientAppointments(String patientId) {
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => Appointment.fromJson(doc.data(), doc.id))
          .toList();
      items.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return items;
    });
  }

  Future<void> updateAppointmentStatus(String appointmentId, String status) {
    return _firestore.collection('appointments').doc(appointmentId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _chatId(String patientId, String doctorId) {
    return '${doctorId}_$patientId';
  }

  String _fallbackDoctorId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9а-яё]+', unicode: true), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
