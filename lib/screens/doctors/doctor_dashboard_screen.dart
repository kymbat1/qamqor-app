import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/appointment.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_design.dart';
import '../auth/login_screen.dart';
import 'chat_list_screen.dart';
import 'doctor_chat_screen.dart';
import 'doctor_profile_editor_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  final AuthService authService;

  const DoctorDashboardScreen({super.key, required this.authService});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  late final AppointmentService _appointmentService;
  String? _doctorId;
  String _filter = 'Все';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _appointmentService = AppointmentService(authService: widget.authService);
    _loadDoctor();
  }

  Future<void> _loadDoctor() async {
    final uid = await widget.authService.currentUser();
    if (!mounted) return;
    setState(() {
      _doctorId = uid;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await widget.authService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(authService: widget.authService),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: GradientPage(child: Center(child: CircularProgressIndicator())),
      );
    }

    final doctorId = _doctorId;
    if (doctorId == null || doctorId.isEmpty) {
      return LoginScreen(authService: widget.authService);
    }

    return Scaffold(
      extendBody: true,
      body: GradientPage(
        child: SafeArea(
          child: StreamBuilder<List<Appointment>>(
            stream: _appointmentService.watchDoctorAppointments(doctorId),
            builder: (context, snapshot) {
              final allAppointments = snapshot.data ?? [];
              final appointments = _filterAppointments(allAppointments);
              final today = allAppointments.where(_isToday).length;
              final active = allAppointments
                  .where((item) =>
                      item.status != 'cancelled' && item.status != 'completed')
                  .length;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FadeSlideIn(child: _topBar()),
                          const SizedBox(height: 16),
                          FadeSlideIn(
                            delayMs: 70,
                            child: _summaryCard(
                              today,
                              active,
                              allAppointments.length,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FadeSlideIn(delayMs: 120, child: _filters()),
                        ],
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (appointments.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: FadeSlideIn(
                                delayMs: index * 30,
                                child: _appointmentCard(appointments[index]),
                              ),
                            );
                          },
                          childCount: appointments.length,
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

  List<Appointment> _filterAppointments(List<Appointment> appointments) {
    if (_filter == 'Все') return appointments;
    if (_filter == 'Сегодня') return appointments.where(_isToday).toList();
    if (_filter == 'Активные') {
      return appointments
          .where((item) => item.status != 'cancelled' && item.status != 'completed')
          .toList();
    }
    if (_filter == 'Завершенные') {
      return appointments.where((item) => item.status == 'completed').toList();
    }
    return appointments.where((item) => item.status == 'cancelled').toList();
  }

  bool _isToday(Appointment appointment) {
    final now = DateTime.now();
    return appointment.dateTime.year == now.year &&
        appointment.dateTime.month == now.month &&
        appointment.dateTime.day == now.day;
  }

  Widget _topBar() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Кабинет врача',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Записи, пациенты и переписка',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Чаты',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatListScreen(
                  authService: widget.authService,
                  isDoctor: true,
                ),
              ),
            );
          },
          icon: const Icon(Icons.forum_outlined),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Профиль',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DoctorProfileEditorScreen(
                  authService: widget.authService,
                ),
              ),
            );
          },
          icon: const Icon(Icons.badge_outlined),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Выйти',
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }

  Widget _summaryCard(int today, int active, int total) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppShadows.floating,
      ),
      child: Row(
        children: [
          _summaryMetric('$today', 'сегодня'),
          _divider(),
          _summaryMetric('$active', 'активные'),
          _divider(),
          _summaryMetric('$total', 'всего'),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 44, color: Colors.white.withOpacity(0.24));
  }

  Widget _summaryMetric(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.82))),
        ],
      ),
    );
  }

  Widget _filters() {
    final items = [
      'Все',
      'Сегодня',
      'Активные',
      'Завершенные',
      'Отмененные',
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = item == _filter;
          return ChoiceChip(
            label: Text(item),
            selected: selected,
            onSelected: (_) => setState(() => _filter = item),
            selectedColor: AppColors.blush,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
            side: BorderSide(color: selected ? AppColors.blush : Colors.white),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: SoftCard(
          radius: 30,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_busy_outlined,
                  color: AppColors.blush, size: 44),
              const SizedBox(height: 14),
              const Text(
                'Записей пока нет',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _filter == 'Все'
                    ? 'Когда пациент запишется к вам, карточка появится здесь.'
                    : 'По выбранному фильтру записей нет.',
                textAlign: TextAlign.center,
                style: const TextStyle(
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

  Widget _appointmentCard(Appointment appointment) {
    final formattedDate =
        DateFormat('d MMMM, HH:mm', 'ru_RU').format(appointment.dateTime);

    return SoftCard(
      radius: 28,
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
                child: const Icon(Icons.person_outline, color: AppColors.plum),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      appointment.patientContact.isEmpty
                          ? 'Контакт не указан'
                          : appointment.patientContact,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              _statusChip(appointment.status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.schedule, color: AppColors.blush, size: 18),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton('Подтвердить', Icons.check_rounded, () {
                _updateStatus(appointment.id, 'confirmed');
              }),
              _actionButton('Завершить', Icons.done_all_rounded, () {
                _updateStatus(appointment.id, 'completed');
              }),
              _actionButton('Отменить', Icons.close_rounded, () {
                _updateStatus(appointment.id, 'cancelled');
              }),
              _actionButton('Чат', Icons.chat_outlined, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DoctorChatScreen(
                      chatId: appointment.chatId,
                      title: appointment.patientName,
                      senderRole: 'doctor',
                      authService: widget.authService,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String appointmentId, String status) async {
    await _appointmentService.updateAppointmentStatus(appointmentId, status);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Статус записи обновлен'),
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
    final text = switch (status) {
      'confirmed' => 'подтверждена',
      'cancelled' => 'отменена',
      'completed' => 'завершена',
      _ => 'новая',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.plum,
        side: BorderSide(color: AppColors.plum.withOpacity(0.14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
