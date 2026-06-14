class ChatThread {
  final String id;
  final String? appointmentId;
  final String clientId;
  final String clientName;
  final String clientContact;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final DateTime? appointmentStartsAt;
  final String appointmentStatus;
  final String lastMessage;
  final DateTime updatedAt;

  const ChatThread({
    required this.id,
    this.appointmentId,
    required this.clientId,
    required this.clientName,
    required this.clientContact,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    this.appointmentStartsAt,
    required this.appointmentStatus,
    required this.lastMessage,
    required this.updatedAt,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id']?.toString() ?? '',
      appointmentId: json['appointment_id']?.toString(),
      clientId: json['client_id']?.toString() ?? '',
      clientName: json['client_name']?.toString() ?? 'Пациент',
      clientContact: json['client_contact']?.toString() ?? '',
      doctorId: json['doctor_id']?.toString() ?? '',
      doctorName: json['doctor_name']?.toString() ?? 'Врач',
      doctorSpecialty: json['doctor_specialty']?.toString() ?? '',
      appointmentStartsAt: _readNullableDate(json['appointment_starts_at']),
      appointmentStatus: json['appointment_status']?.toString() ?? '',
      lastMessage: json['last_message']?.toString() ?? '',
      updatedAt: _readNullableDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  static DateTime? _readNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String senderRole;
  final String text;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      chatId: json['chat_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderRole: json['sender_role']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      createdAt: ChatThread._readNullableDate(json['created_at']) ?? DateTime.now(),
    );
  }
}
