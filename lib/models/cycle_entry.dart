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
  final String? cyclePhase;
  final double? weightKg;
  final double? heightCm;
  final double? temperatureC;
  final double? sleepHours;
  final int? painLevel;
  final int? energyLevel;
  final int? stressLevel;
  final String? discharge;
  final String? libido;
  final String? appetite;
  final String? activity;
  final String? medication;
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
    this.cyclePhase,
    this.weightKg,
    this.heightCm,
    this.temperatureC,
    this.sleepHours,
    this.painLevel,
    this.energyLevel,
    this.stressLevel,
    this.discharge,
    this.libido,
    this.appetite,
    this.activity,
    this.medication,
    this.note,
    this.createdAt,
    this.updatedAt,
  }) : dayKey = dayKey ?? dateKey(date);

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'date': dateKey(date),
        'dayKey': dayKey,
        'cycleDay': cycleDay,
        'isPeriodDay': isPeriodDay,
        'flow': flow,
        'mood': mood,
        'symptoms': symptoms,
        'cyclePhase': cyclePhase,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'temperatureC': temperatureC,
        'sleepHours': sleepHours,
        'painLevel': painLevel,
        'energyLevel': energyLevel,
        'stressLevel': stressLevel,
        'discharge': discharge,
        'libido': libido,
        'appetite': appetite,
        'activity': activity,
        'medication': medication,
        'note': note,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  Map<String, dynamic> toApiJson() => {
        'day_key': dayKey,
        'cycle_day': cycleDay,
        'is_period_day': isPeriodDay,
        'flow': flow,
        'mood': mood,
        'symptoms': symptoms,
        'cycle_phase': cyclePhase,
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'temperature_c': temperatureC,
        'sleep_hours': sleepHours,
        'pain_level': painLevel,
        'energy_level': energyLevel,
        'stress_level': stressLevel,
        'discharge': discharge,
        'libido': libido,
        'appetite': appetite,
        'activity': activity,
        'medication': medication,
        'note': note,
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
    String? cyclePhase,
    double? weightKg,
    double? heightCm,
    double? temperatureC,
    double? sleepHours,
    int? painLevel,
    int? energyLevel,
    int? stressLevel,
    String? discharge,
    String? libido,
    String? appetite,
    String? activity,
    String? medication,
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
      cyclePhase: cyclePhase ?? this.cyclePhase,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      temperatureC: temperatureC ?? this.temperatureC,
      sleepHours: sleepHours ?? this.sleepHours,
      painLevel: painLevel ?? this.painLevel,
      energyLevel: energyLevel ?? this.energyLevel,
      stressLevel: stressLevel ?? this.stressLevel,
      discharge: discharge ?? this.discharge,
      libido: libido ?? this.libido,
      appetite: appetite ?? this.appetite,
      activity: activity ?? this.activity,
      medication: medication ?? this.medication,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CycleEntry.fromJson(Map<String, dynamic> json, {String? id}) {
    final rawDayKey = json['dayKey'] ?? json['day_key'];
    final date = _readDate(json['date']) ??
        _readDate(rawDayKey) ??
        DateTime.now();
    return CycleEntry(
      id: id ?? json['id']?.toString(),
      userId: json['userId'] ?? json['user_id'],
      date: DateTime(date.year, date.month, date.day),
      dayKey: rawDayKey?.toString() ?? dateKey(date),
      cycleDay: _readInt(json['cycleDay'] ?? json['cycle_day']) ?? 1,
      isPeriodDay: json['isPeriodDay'] ?? json['is_period_day'] ?? true,
      flow: json['flow'],
      mood: json['mood'],
      symptoms: _readSymptoms(json['symptoms']),
      cyclePhase: json['cyclePhase'] ?? json['cycle_phase'],
      weightKg: _readDouble(json['weightKg'] ?? json['weight_kg']),
      heightCm: _readDouble(json['heightCm'] ?? json['height_cm']),
      temperatureC: _readDouble(json['temperatureC'] ?? json['temperature_c']),
      sleepHours: _readDouble(json['sleepHours'] ?? json['sleep_hours']),
      painLevel: _readInt(json['painLevel'] ?? json['pain_level']),
      energyLevel: _readInt(json['energyLevel'] ?? json['energy_level']),
      stressLevel: _readInt(json['stressLevel'] ?? json['stress_level']),
      discharge: json['discharge'],
      libido: json['libido'],
      appetite: json['appetite'],
      activity: json['activity'],
      medication: json['medication'],
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

  static double? _readDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
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
