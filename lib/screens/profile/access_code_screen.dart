import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_design.dart';

class AccessCodeScreen extends StatefulWidget {
  const AccessCodeScreen({super.key});

  @override
  State<AccessCodeScreen> createState() => _AccessCodeScreenState();
}

class _AccessCodeScreenState extends State<AccessCodeScreen> {
  final AuthService _authService = AuthService();
  final _pinController = TextEditingController();
  final _repeatController = TextEditingController();

  bool _enabled = false;
  bool _biometricHint = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _authService.currentUserData();
    final security = data?['security'];
    if (!mounted) return;

    if (security is Map) {
      setState(() {
        _enabled = security['accessCodeEnabled'] ?? false;
        _biometricHint = security['biometricHint'] ?? true;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_enabled) {
      final pin = _pinController.text.trim();
      final repeat = _repeatController.text.trim();
      if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
        _showMessage('PIN должен состоять из 4 цифр');
        return;
      }
      if (pin != repeat) {
        _showMessage('PIN-коды не совпадают');
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      await _authService.updateCurrentUserProfile({
        'security': {
          'accessCodeEnabled': _enabled,
          'accessCodeHash': _enabled ? _hashPin(_pinController.text.trim()) : null,
          'biometricHint': _biometricHint,
        },
      });
      if (!mounted) return;
      _pinController.clear();
      _repeatController.clear();
      _showMessage('Настройки доступа сохранены');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Не удалось сохранить PIN');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _repeatController.dispose();
    super.dispose();
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
                  title: 'Код доступа',
                  subtitle: 'Защита личных данных',
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(child: _hero()),
                const SizedBox(height: 16),
                FadeSlideIn(delayMs: 80, child: _settings()),
                const SizedBox(height: 18),
                GradientButton(
                  label: 'Сохранить',
                  icon: Icons.lock_rounded,
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

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppShadows.floating,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.blush,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.verified_user_rounded, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _enabled
                  ? 'PIN включен. Код хранится в виде хеша.'
                  : 'Включи PIN, чтобы защитить календарь и записи.',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settings() {
    return SoftCard(
      radius: 30,
      child: Column(
        children: [
          SwitchListTile(
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.password_rounded, color: AppColors.blush),
            title: const Text(
              'Включить PIN',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: const Text('4 цифры для быстрого доступа'),
          ),
          if (_enabled) ...[
            const SizedBox(height: 10),
            _pinField(_pinController, 'Новый PIN'),
            const SizedBox(height: 12),
            _pinField(_repeatController, 'Повторить PIN'),
          ],
          const Divider(height: 28),
          SwitchListTile(
            value: _biometricHint,
            onChanged: (value) => setState(() => _biometricHint = value),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.fingerprint_rounded, color: AppColors.blush),
            title: const Text(
              'Биометрия',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: const Text('Подготовлено для Face ID / отпечатка'),
          ),
        ],
      ),
    );
  }

  Widget _pinField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 4,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        prefixIcon: const Icon(Icons.pin_rounded, color: AppColors.blush),
      ),
    );
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode('qamqor:$pin')).toString();
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
