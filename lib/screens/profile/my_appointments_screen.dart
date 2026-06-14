import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/appointment.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_design.dart';
import '../doctors/doctor_chat_screen.dart';

class MyAppointmentsScreen extends StatefulWidget {
  final AuthService authService;

  const MyAppointmentsScreen({super.key, required this.authService});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  late final AppointmentService _appointmentService;
  String? _patientId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _appointmentService = AppointmentService(authService: widget.authService);
    _loadPatient();
  }

  Future<void> _loadPatient() async {
    final uid = await widget.authService.currentUser();
    if (!mounted) return;
    setState(() {
      _patientId = uid;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: GradientPage(child: Center(child: CircularProgressIndicator())),
      );
    }

    final patientId = _patientId;
    if (patientId == null || patientId.isEmpty) {
      return const Scaffold(
        body: GradientPage(child: Center(child: Text('Войдите в аккаунт'))),
      );
    }

    return Scaffold(
      extendBody: true,
      body: GradientPage(
        child: SafeArea(
          child: StreamBuilder<List<Appointment>>(
            stream: _appointmentService.watchPatientAppointments(patientId),
            builder: (context, snapshot) {
              final appointments = snapshot.data ?? [];
              final upcoming = appointments
                  .where((item) =>
                      item.dateTime.isAfter(DateTime.now()) &&
                      item.status != 'cancelled')
                  .length;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(
                            title: 'Мои записи',
                            subtitle: 'Консультации, статусы и чаты',
                            onBack: () => Navigator.pop(context),
                          ),
                          const SizedBox(height: 18),
                          _summary(appointments.length, upcoming),
                        ],
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (appointments.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyAppointments(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final appointmentIndex = index ~/ 2;
                            if (index.isOdd) return const SizedBox(height: 12);
                            return _appointmentCard(
                              appointments[appointmentIndex],
                            );
                          },
                          childCount: appointments.length * 2 - 1,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _summary(int total, int upcoming) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppShadows.floating,
      ),
      child: Row(
        children: [
          _metric(total.toString(), 'всего'),
          _metric(upcoming.toString(), 'активные'),
          _metric(DateFormat('MMM', 'ru_RU').format(DateTime.now()), 'месяц'),
        ],
      ),
    );
  }

  Widget _metric(String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appointmentCard(Appointment appointment) {
    final formattedDate =
        DateFormat('d MMMM, HH:mm', 'ru_RU').format(appointment.dateTime);
    final isClosed =
        appointment.status == 'cancelled' || appointment.status == 'completed';

    return SoftCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.lavender,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: AppColors.blush,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.doctorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      appointment.doctorSpecialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(appointment.status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  color: AppColors.blush, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formattedDate,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openChat(appointment),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Чат'),
                ),
              ),
              if (!isClosed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelAppointment(appointment),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Отменить'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _openChat(Appointment appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorChatScreen(
          chatId: appointment.chatId,
          title: appointment.doctorName,
          senderRole: 'client',
          authService: widget.authService,
        ),
      ),
    );
  }

  Future<void> _cancelAppointment(Appointment appointment) async {
    await _appointmentService.updateAppointmentStatus(
      appointment.id,
      'cancelled',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Запись отменена'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'confirmed' => const Color(0xFF3FA178),
      'cancelled' => Colors.redAccent,
      'completed' => Colors.blueGrey,
      _ => AppColors.blush,
    };
    final label = switch (status) {
      'confirmed' => 'подтверждена',
      'cancelled' => 'отменена',
      'completed' => 'завершена',
      _ => 'запланирована',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyAppointments extends StatelessWidget {
  const _EmptyAppointments();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: SoftCard(
          radius: 30,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.lavender,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: AppColors.blush,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Записей пока нет',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Выберите врача и удобное время, чтобы консультация появилась здесь.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
