import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/auth_code.dart';
import '../../services/auth_service.dart';
import '../../theme/app_design.dart';
import '../../utils/auth_validators.dart';
import '../main_wrapper.dart';

class OtpVerificationScreen extends StatefulWidget {
  final AuthService authService;
  final OtpChannel channel;
  final String recipient;
  final DateTime expiresAt;
  final String? debugCode;
  final String requestedRole;

  const OtpVerificationScreen({
    super.key,
    required this.authService,
    required this.channel,
    required this.recipient,
    required this.expiresAt,
    this.debugCode,
    this.requestedRole = 'patient',
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;
  late DateTime _expiresAt;
  String? _debugCode;
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _expiresAt = widget.expiresAt;
    _debugCode = widget.debugCode;
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (!AuthValidators.isValidCode(code)) {
      _showMessage('Введите 6 цифр из сообщения');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await widget.authService.verifyOtp(
        channel: widget.channel,
        recipient: widget.recipient,
        code: code,
        requestedRole: widget.requestedRole,
      );

      if (!mounted) return;
      _showMessage('Вход выполнен');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MainWrapper(authService: widget.authService),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(_messageForError(e));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);
    try {
      final result = await widget.authService.requestOtp(
        channel: widget.channel,
        recipient: widget.recipient,
      );

      if (!mounted) return;
      setState(() {
        _expiresAt = result.expiresAt;
        _debugCode = result.debugCode;
        _codeController.clear();
      });
      _showMessage('Новый код отправлен');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_messageForError(e));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String _messageForError(Object error) {
    final text = error.toString();
    if (text.contains('otp-invalid')) return 'Неверный код';
    if (text.contains('otp-expired')) {
      return 'Срок действия кода истек. Запросите новый код.';
    }
    if (text.contains('otp-too-many-attempts')) {
      return 'Слишком много попыток. Запросите новый код позже.';
    }
    if (text.contains('otp-resend-too-soon')) {
      return 'Повторная отправка будет доступна через минуту.';
    }
    if (text.contains('otp-not-found')) {
      return 'Код не найден. Запросите новый код.';
    }
    return 'Не удалось подтвердить код';
  }

  void _tick() {
    final diff = _expiresAt.difference(DateTime.now());
    if (!mounted) return;
    setState(() {
      _timeLeft = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0');

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
                const SizedBox(height: 18),
                const Icon(
                  Icons.verified_user_outlined,
                  size: 72,
                  color: AppColors.blush,
                ),
                const SizedBox(height: 18),
                Text(
                  'Код из ${widget.channel.title}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Мы отправили код на ${widget.recipient}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_debugCode != null) ...[
                  const SizedBox(height: 16),
                  SoftCard(
                    radius: 22,
                    color: AppColors.lavender,
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Тестовый код: $_debugCode',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.plum,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    labelText: '6-значный код',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Код действует $minutes:$seconds',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Подтвердить',
                  icon: Icons.check_rounded,
                  isLoading: _isVerifying,
                  onPressed: _verifyCode,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isResending ? null : _resendCode,
                  child: _isResending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Отправить код еще раз'),
                ),
              ],
            ),
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
