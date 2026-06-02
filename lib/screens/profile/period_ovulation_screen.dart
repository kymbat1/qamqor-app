import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_design.dart';

class PeriodOvulationScreen extends StatefulWidget {
  const PeriodOvulationScreen({super.key});

  @override
  State<PeriodOvulationScreen> createState() => _PeriodOvulationScreenState();
}

class _PeriodOvulationScreenState extends State<PeriodOvulationScreen> {
  final AuthService _authService = AuthService();

  double _cycleLength = 28;
  double _periodLength = 5;
  double _lutealLength = 14;
  bool _fertileWindow = true;
  bool _pmsHints = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final data = await _authService.currentUserData();
    final settings = data?['cycleSettings'];

    if (!mounted) return;
    if (settings is Map) {
      setState(() {
        _cycleLength = _readDouble(settings['cycleLength'], 28);
        _periodLength = _readDouble(settings['periodLength'], 5);
        _lutealLength = _readDouble(settings['lutealLength'], 14);
        _fertileWindow = settings['fertileWindow'] ?? true;
        _pmsHints = settings['pmsHints'] ?? true;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _authService.updateCurrentUserProfile({
        'cycleSettings': {
          'cycleLength': _cycleLength.round(),
          'periodLength': _periodLength.round(),
          'lutealLength': _lutealLength.round(),
          'fertileWindow': _fertileWindow,
          'pmsHints': _pmsHints,
        },
      });
      if (!mounted) return;
      _showMessage('Настройки цикла сохранены');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Не удалось сохранить настройки');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: GradientPage(child: Center(child: CircularProgressIndicator())),
      );
    }

    final ovulationDay = (_cycleLength - _lutealLength).round();

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
                  title: 'Цикл',
                  subtitle: 'Прогнозы и овуляция',
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(child: _hero(ovulationDay)),
                const SizedBox(height: 16),
                FadeSlideIn(delayMs: 80, child: _settingsCard()),
                const SizedBox(height: 18),
                GradientButton(
                  label: 'Сохранить настройки',
                  icon: Icons.check_rounded,
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

  Widget _hero(int ovulationDay) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppShadows.floating,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.favorite_rounded, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Расчет прогноза',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Овуляция около $ovulationDay дня',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard() {
    return SoftCard(
      radius: 30,
      child: Column(
        children: [
          _slider(
            title: 'Длина цикла',
            value: _cycleLength,
            min: 21,
            max: 45,
            suffix: 'дней',
            onChanged: (value) => setState(() => _cycleLength = value),
          ),
          _slider(
            title: 'Длина месячных',
            value: _periodLength,
            min: 2,
            max: 10,
            suffix: 'дней',
            onChanged: (value) => setState(() => _periodLength = value),
          ),
          _slider(
            title: 'Лютеиновая фаза',
            value: _lutealLength,
            min: 10,
            max: 16,
            suffix: 'дней',
            onChanged: (value) => setState(() => _lutealLength = value),
          ),
          const Divider(height: 28),
          _switchTile(
            icon: Icons.spa_rounded,
            title: 'Фертильное окно',
            subtitle: 'Показывать дни повышенной вероятности',
            value: _fertileWindow,
            onChanged: (value) => setState(() => _fertileWindow = value),
          ),
          _switchTile(
            icon: Icons.self_improvement_rounded,
            title: 'Подсказки ПМС',
            subtitle: 'Мягкие рекомендации в конце цикла',
            value: _pmsHints,
            onChanged: (value) => setState(() => _pmsHints = value),
          ),
        ],
      ),
    );
  }

  Widget _slider({
    required String title,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${value.round()} $suffix',
                style: const TextStyle(
                  color: AppColors.blush,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
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

  double _readDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
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
