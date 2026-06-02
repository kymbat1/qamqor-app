import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorReview {
  final String id;
  final String doctorId;
  final String patientId;
  final String patientName;
  final double rating;
  final String text;
  final DateTime createdAt;

  const DoctorReview({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.rating,
    required this.text,
    required this.createdAt,
  });

  factory DoctorReview.fromJson(Map<String, dynamic> json, String id) {
    return DoctorReview(
      id: id,
      doctorId: json['doctorId'] ?? '',
      patientId: json['patientId'] ?? '',
      patientName: json['patientName'] ?? 'Пациент',
      rating: _readDouble(json['rating'], 5),
      text: json['text'] ?? '',
      createdAt: _readDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doctorId': doctorId,
      'patientId': patientId,
      'patientName': patientName,
      'rating': rating,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static double _readDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}

final List<DoctorReview> seedDoctorReviews = [
  DoctorReview(
    id: 'seed-1',
    doctorId: 'asel-satova',
    patientId: 'seed',
    patientName: 'Аружан',
    rating: 5,
    text: 'Очень спокойно объяснила результаты и дала понятный план действий.',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
  DoctorReview(
    id: 'seed-2',
    doctorId: 'lyazzat-kuanysheva',
    patientId: 'seed',
    patientName: 'Мадина',
    rating: 4.8,
    text: 'Прием прошел деликатно, без лишнего стресса. Спасибо за внимательность.',
    createdAt: DateTime.now().subtract(const Duration(days: 8)),
  ),
];
