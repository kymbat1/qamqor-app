import 'package:cloud_firestore/cloud_firestore.dart';

class CycleEntry {
  final String? id;
  final String? userId;
  final DateTime date;
  final String dayKey;
  final int cycleDay;
  final bool isPeriodDay;
  final String? flow;
  final String? mood;
  final List<String> symptoms;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CycleEntry({
    this.id,
    this.userId,
    required this.date,
    String? dayKey,
    required this.cycleDay,
    this.isPeriodDay = true,
    this.flow,
    this.mood,
    this.symptoms = const [],
    this.note,
    this.createdAt,
    this.updatedAt,
  }) : dayKey = dayKey ?? dateKey(date);

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        'dayKey': dayKey,
        'cycleDay': cycleDay,
        'isPeriodDay': isPeriodDay,
        'flow': flow,
        'mood': mood,
        'symptoms': symptoms,
        'note': note,
        'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
        'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      };

  CycleEntry copyWith({
    String? id,
    String? userId,
    DateTime? date,
    String? dayKey,
    int? cycleDay,
    bool? isPeriodDay,
    String? flow,
    String? mood,
    List<String>? symptoms,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CycleEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      dayKey: dayKey ?? this.dayKey,
      cycleDay: cycleDay ?? this.cycleDay,
      isPeriodDay: isPeriodDay ?? this.isPeriodDay,
      flow: flow ?? this.flow,
      mood: mood ?? this.mood,
      symptoms: symptoms ?? this.symptoms,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CycleEntry.fromJson(Map<String, dynamic> json, {String? id}) {
    final date = _readDate(json['date']) ?? DateTime.now();
    return CycleEntry(
      id: id,
      userId: json['userId'],
      date: DateTime(date.year, date.month, date.day),
      dayKey: json['dayKey'] ?? dateKey(date),
      cycleDay: _readInt(json['cycleDay']) ?? 1,
      isPeriodDay: json['isPeriodDay'] ?? true,
      flow: json['flow'],
      mood: json['mood'],
      symptoms: _readSymptoms(json['symptoms']),
      note: json['note'],
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  static String dateKey(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static DateTime normalizedDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static List<String> _readSymptoms(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return [value.trim()];
    }
    return [];
  }
}
