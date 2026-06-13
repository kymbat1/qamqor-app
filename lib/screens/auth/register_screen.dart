import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_design.dart';
import '../../utils/auth_validators.dart';
import '../main_wrapper.dart';

class RegisterScreen extends StatefulWidget {
  final AuthService authService;

  const RegisterScreen({super.key, required this.authService});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _codeSent = false;
  String _role = 'client';
  String _status = '';
  String? _debugCode;
  DateTime? _expiresAt;
  DateTime? _resendAvailableAt;
  Timer? _timer;
  int _tick = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.length < 2) {
      _showMessage('Введите имя');
      return;
    }
    if (!AuthValidators.isValidEmail(email)) {
      _showMessage('Введите корректный email');
      return;
    }
    if (password.length < 8) {
      _showMessage('Пароль должен быть минимум 8 символов');
      return;
    }
    if (password != confirmPassword) {
      _showMessage('Пароли не совпадают');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Отправляем код подтверждения...';
    });

    try {
      final result = await widget.authService.startEmailRegistration(
        name: name,
        email: email,
        password: password,
        role: _role,
        website: _websiteController.text,
      );
      if (!mounted) return;
      _startTicker();
      setState(() {
        _codeSent = true;
        _debugCode = result.debugCode;
        _expiresAt = result.expiresAt;
        _resendAvailableAt = result.resendAvailableAt;
        _status = 'Код отправлен на ${result.email}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '');
      _showMessage(_messageForError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    if (!AuthValidators.isValidCode(code)) {
      _showMessage('Введите 6 цифр из письма');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Проверяем код...';
    });

    try {
      await widget.authService.verifyEmailRegistration(
        email: email,
        code: code,
      );
      if (!mounted) return;
      setState(() => _status = 'Email подтвержден. Регистрация завершена.');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MainWrapper(authService: widget.authService),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Код не подтвержден');
      _showMessage(_messageForError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) {
      _showMessage('Повторная отправка будет доступна через $_resendSeconds сек.');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Отправляем новый код...';
    });

    try {
      final result = await widget.authService.resendEmailRegistrationCode(
        email: _emailController.text.trim(),
        website: _websiteController.text,
      );
      if (!mounted) return;
      _startTicker();
      setState(() {
        _debugCode = result.debugCode;
        _expiresAt = result.expiresAt;
        _resendAvailableAt = result.resendAvailableAt;
        _status = 'Новый код отправлен';
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(_messageForError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _canResend {
    final resendAt = _resendAvailableAt;
    return resendAt == null || DateTime.now().isAfter(resendAt);
  }

  int get _resendSeconds {
    final resendAt = _resendAvailableAt;
    if (resendAt == null) return 0;
    final seconds = resendAt.difference(DateTime.now()).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  String get _expiryText {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return '';
    final minutes = expiresAt.difference(DateTime.now()).inMinutes;
    if (minutes <= 0) return 'Срок действия кода истек';
    return 'Код действует еще $minutes мин.';
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _tick++);
      }
    });
  }

  String _messageForError(Object error) {
    final text = error.toString();
    if (text.contains('email-already-in-use')) {
      return 'Такой email уже зарегистрирован';
    }
    if (text.contains('weak-password')) {
      return 'Пароль слишком простой';
    }
    if (text.contains('invalid-email')) {
      return 'Некорректный email';
    }
    if (text.contains('verification-code-invalid')) {
      return 'Неверный код. Проверьте письмо и попробуйте еще раз.';
    }
    if (text.contains('verification-code-expired')) {
      return 'Код истек. Отправьте новый код.';
    }
    if (text.contains('verification-code-not-found')) {
      return 'Сначала запросите код подтверждения.';
    }
    if (text.contains('otp-resend-too-soon')) {
      return 'Новый код можно отправить чуть позже.';
    }
    if (text.contains('otp-too-many-attempts')) {
      return 'Слишком много неверных попыток. Запросите новый код.';
    }
    if (text.contains('otp-too-many-requests')) {
      return 'Слишком много запросов. Подождите несколько минут.';
    }
    if (text.contains('email-send-failed')) {
      return 'Не удалось отправить письмо. Проверьте настройки SMTP.';
    }
    if (text.contains('backend-unavailable')) {
      return 'Backend недоступен. Проверьте, что FastAPI запущен на 8000.';
    }
    return 'Не удалось завершить регистрацию';
  }

  @override
  Widget build(BuildContext context) {
    final _ = _tick;
    return Scaffold(
      body: GradientPage(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  child: Text(
                    _codeSent ? 'Подтвердите email' : 'Создать аккаунт',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  delayMs: 80,
                  child: Text(
                    _codeSent
                        ? 'Мы отправили одноразовый код. Введите его ниже, чтобы завершить регистрацию.'
                        : 'Введите email и пароль. Аккаунт будет создан только после подтверждения кода.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: _codeSent ? _verificationCard() : _registrationCard(),
                ),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _statusPill(),
                ],
                const SizedBox(height: 18),
                GradientButton(
                  label: _codeSent ? 'Подтвердить код' : 'Получить код',
                  icon: _codeSent
                      ? Icons.verified_user_outlined
                      : Icons.mark_email_read_outlined,
                  isLoading: _isLoading,
                  onPressed: _codeSent ? _verifyCode : _requestCode,
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _isLoading ? null : _resendCode,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      _canResend
                          ? 'Отправить код повторно'
                          : 'Повторно через $_resendSeconds сек.',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _registrationCard() {
    return SoftCard(
      key: const ValueKey('registration'),
      radius: 28,
      child: Column(
        children: [
          Offstage(
            child: TextField(
              controller: _websiteController,
              autofillHints: const ['off'],
            ),
          ),
          _field(_nameController, 'Имя', Icons.person_outline),
          _field(
            _emailController,
            'Email',
            Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          _roleSelector(),
          _passwordField(),
          _field(
            _confirmPasswordController,
            'Повторите пароль',
            Icons.lock_outline,
            obscureText: true,
          ),
        ],
      ),
    );
  }

  Widget _verificationCard() {
    return SoftCard(
      key: const ValueKey('verification'),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.coral.withValues(alpha: 0.24)),
            ),
            child: Row(
              children: [
                const Icon(Icons.mail_outline_rounded, color: AppColors.blush),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _emailController.text.trim(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.w900,
            ),
            decoration: const InputDecoration(
              counterText: '',
              labelText: 'Код из письма',
              prefixIcon: Icon(Icons.pin_outlined, color: AppColors.blush),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _expiryText,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_debugCode != null && _debugCode!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Локальный debug-код: $_debugCode',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.blush.withValues(alpha: 0.14)),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.blush),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _status,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'client',
            icon: Icon(Icons.person_outline),
            label: Text('Клиент'),
          ),
          ButtonSegment(
            value: 'doctor',
            icon: Icon(Icons.medical_services_outlined),
            label: Text('Доктор'),
          ),
        ],
        selected: {_role},
        onSelectionChanged: (selection) {
          setState(() => _role = selection.first);
        },
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.blush),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        decoration: InputDecoration(
          labelText: 'Пароль',
          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.blush),
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () {
              setState(() => _isPasswordVisible = !_isPasswordVisible);
            },
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
