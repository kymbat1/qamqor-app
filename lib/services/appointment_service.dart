import '../models/appointment.dart';
import '../models/doctor.dart';
import 'api_client.dart';
import 'auth_service.dart';

class AppointmentService {
  final ApiClient _apiClient;

  AppointmentService({AuthService? authService})
      : _apiClient = ApiClient();

  Future<Appointment> createAppointment({
    required Doctor doctor,
    required DateTime dateTime,
  }) async {
    final response = await _apiClient.post('/appointments', body: {
      'doctor_id': doctor.id.isNotEmpty ? doctor.id : _fallbackDoctorId(doctor.name),
      'starts_at': dateTime.toUtc().toIso8601String(),
      'reason': '',
    });
    return Appointment.fromJson(response, response['id']?.toString() ?? '');
  }

  Stream<List<Appointment>> watchDoctorAppointments(String doctorId) {
    return Stream.fromFuture(_fetchAppointments());
  }

  Stream<List<Appointment>> watchPatientAppointments(String patientId) {
    return Stream.fromFuture(_fetchAppointments());
  }

  Future<void> updateAppointmentStatus(String appointmentId, String status) {
    return _apiClient.patch(
      '/appointments/$appointmentId/status',
      body: {'status': status},
    );
  }

  Future<List<Appointment>> _fetchAppointments() async {
    final response = await _apiClient.getList('/appointments');
    final items = response
        .whereType<Map<String, dynamic>>()
        .map((json) => Appointment.fromJson(json, json['id']?.toString() ?? ''))
        .toList();
    items.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return items;
  }

  String _fallbackDoctorId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9а-яё]+', unicode: true), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
