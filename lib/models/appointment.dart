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
      patientId: json['patientId'] ?? json['client_id'] ?? '',
      patientName: json['patientName'] ?? json['client_name'] ?? '',
      patientContact: json['patientContact'] ?? json['client_contact'] ?? '',
      doctorId: json['doctorId'] ?? json['doctor_id'] ?? '',
      doctorName: json['doctorName'] ?? json['doctor_name'] ?? '',
      doctorSpecialty: json['doctorSpecialty'] ?? json['doctor_specialty'] ?? '',
      dateTime: _readDate(json['dateTime'] ?? json['starts_at']),
      status: json['status'] ?? 'scheduled',
      chatId: json['chatId'] ?? json['chat_id'] ?? '',
      createdAt: json['createdAt'] == null && json['created_at'] == null
          ? null
          : _readDate(json['createdAt'] ?? json['created_at']),
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
      'dateTime': dateTime.toIso8601String(),
      'status': status,
      'chatId': chatId,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  static DateTime _readDate(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
  }
}
