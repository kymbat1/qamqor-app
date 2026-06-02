import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_design.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final AuthService _authService = AuthService();

  bool _periodReminder = true;
  bool _ovulationReminder = true;
  bool _appointmentReminder = true;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _authService.currentUserData();
    final reminders = data?['reminders'];

    if (!mounted) return;
    if (reminders is Map) {
      final time = reminders['time']?.toString() ?? '09:00';
      final parts = time.split(':');
      setState(() {
        _periodReminder = reminders['period'] ?? true;
        _ovulationReminder = reminders['ovulation'] ?? true;
        _appointmentReminder = reminders['appointments'] ?? true;
        _time = TimeOfDay(
          hour: int.tryParse(parts.first) ?? 9,
          minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
        );
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) {
      setState(() => _time = selected);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _authService.updateCurrentUserProfile({
        'reminders': {
          'period': _periodReminder,
          'ovulation': _ovulationReminder,
          'appointments': _appointmentReminder,
          'time': _timeString,
        },
      });
      if (!mounted) return;
      _showMessage('Напоминания сохранены');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Не удалось сохранить напоминания');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String get _timeString {
    final hour = _time.hour.toString().padLeft(2, '0');
    final minute = _time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: GradientPage(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      extendBody: true,
      body: GradientPage(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  title: 'Напоминания',
                  subtitle: 'Ритм заботы о себе',
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(child: _timeCard()),
                const SizedBox(height: 16),
                FadeSlideIn(delayMs: 80, child: _toggles()),
                const SizedBox(height: 18),
                GradientButton(
                  label: 'Сохранить',
                  icon: Icons.notifications_active_rounded,
                  isLoading: _isSaving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppShadows.floating,
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: Colors.white, size: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Время уведомлений',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _timeString,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: _pickTime,
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
    );
  }

  Widget _toggles() {
    return SoftCard(
      radius: 30,
      child: Column(
        children: [
          _switchTile(
            icon: Icons.water_drop_rounded,
            title: 'Месячные',
            subtitle: 'Предупреждать о начале цикла',
            value: _periodReminder,
            onChanged: (value) => setState(() => _periodReminder = value),
          ),
          _switchTile(
            icon: Icons.spa_rounded,
            title: 'Овуляция',
            subtitle: 'Напоминать о фертильном окне',
            value: _ovulationReminder,
            onChanged: (value) => setState(() => _ovulationReminder = value),
          ),
          _switchTile(
            icon: Icons.medical_services_rounded,
            title: 'Записи к врачу',
            subtitle: 'Не забывать о консультациях',
            value: _appointmentReminder,
            onChanged: (value) => setState(() => _appointmentReminder = value),
          ),
        ],
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: AppColors.blush),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(subtitle),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
