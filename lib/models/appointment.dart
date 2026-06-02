import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String patientContact;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final DateTime dateTime;
  final String status;
  final String chatId;
  final DateTime? createdAt;

  const Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientContact,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.dateTime,
    required this.status,
    required this.chatId,
    this.createdAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json, String id) {
    return Appointment(
      id: id,
      patientId: json['patientId'] ?? '',
      patientName: json['patientName'] ?? '',
      patientContact: json['patientContact'] ?? '',
      doctorId: json['doctorId'] ?? '',
      doctorName: json['doctorName'] ?? '',
      doctorSpecialty: json['doctorSpecialty'] ?? '',
      dateTime: _readDate(json['dateTime']),
      status: json['status'] ?? 'scheduled',
      chatId: json['chatId'] ?? '',
      createdAt: json['createdAt'] == null ? null : _readDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'patientContact': patientContact,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'doctorSpecialty': doctorSpecialty,
      'dateTime': Timestamp.fromDate(dateTime),
      'status': status,
      'chatId': chatId,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }
}
