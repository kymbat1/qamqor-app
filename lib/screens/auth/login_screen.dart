import 'package:flutter/material.dart';

import '../../models/auth_code.dart';
import '../../services/auth_service.dart';
import '../../theme/app_design.dart';
import '../../utils/auth_validators.dart';
import '../main_wrapper.dart';
import 'otp_verification_screen.dart';
import 'register_screen.dart';

enum LoginMethod {
  password,
  otp,
}

class LoginScreen extends StatefulWidget {
  final AuthService authService;

  const LoginScreen({super.key, required this.authService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  LoginMethod _method = LoginMethod.password;
  OtpChannel _channel = OtpChannel.email;
  String _role = 'patient';
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _recipientController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!AuthValidators.isValidEmail(email)) {
      _showMessage('Введите корректный email');
      return;
    }
    if (password.length < 6) {
      _showMessage('Пароль должен быть минимум 6 символов');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.authService.signIn(email, password);
      if (!mounted) return;
      _openApp();
    } catch (e) {
      if (!mounted) return;
      _showMessage(_passwordMessageForError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestCode() async {
    final rawValue = _recipientController.text.trim();
    final value = _channel == OtpChannel.email
        ? AuthValidators.normalizeEmail(rawValue)
        : AuthValidators.normalizePhone(rawValue);
    final isValid = _channel == OtpChannel.email
        ? AuthValidators.isValidEmail(value)
        : AuthValidators.isValidPhone(value);

    if (!isValid) {
      _showMessage(
        _channel == OtpChannel.email
            ? 'Введите корректный email'
            : 'Введите номер WhatsApp в формате +77001234567',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await widget.authService.requestOtp(
        channel: _channel,
        recipient: value,
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            authService: widget.authService,
            channel: result.channel,
            recipient: result.recipient,
            expiresAt: result.expiresAt,
            debugCode: result.debugCode,
            requestedRole: _role,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(_otpMessageForError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _passwordMessageForError(Object error) {
    final text = error.toString();
    if (text.contains('user-not-found')) {
      return 'Пользователь не найден. Зарегистрируйтесь.';
    }
    if (text.contains('wrong-password') || text.contains('invalid-credential')) {
      return 'Неверный email или пароль.';
    }
    if (text.contains('invalid-email')) return 'Некорректный email.';
    return 'Не удалось войти по паролю.';
  }

  String _otpMessageForError(Object error) {
    final text = error.toString();
    if (text.contains('otp-resend-too-soon')) {
      return 'Код уже отправлен. Повторная отправка будет доступна через минуту.';
    }
    if (text.contains('otp-too-many-requests')) {
      return 'Слишком много запросов кода. Попробуйте позже.';
    }
    if (text.contains('invalid-email')) return 'Некорректный email.';
    if (text.contains('invalid-phone')) return 'Некорректный номер телефона.';
    if (text.contains('otp-delivery-failed')) {
      return 'Не удалось отправить код. Для проверки включите OTP_DELIVERY_MODE=debug.';
    }
    return 'Не удалось отправить код.';
  }

  @override
  Widget build(BuildContext context) {
    final isPassword = _method == LoginMethod.password;

    return Scaffold(
      body: GradientPage(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeSlideIn(child: _buildHero()),
                const SizedBox(height: 24),
                FadeSlideIn(delayMs: 80, child: _buildAuthCard(isPassword)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: AppColors.blush,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppShadows.soft,
          ),
          child: const Icon(Icons.favorite, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 22),
        const Text(
          'Qamqor',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 42,
            fontWeight: FontWeight.w900,
            height: 0.95,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Цикл, запись к врачу и забота о себе в одном удобном приложении.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard(bool isPassword) {
    return FrostedPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<LoginMethod>(
            segments: const [
              ButtonSegment(
                value: LoginMethod.password,
                icon: Icon(Icons.lock_outline),
                label: Text('Пароль'),
              ),
              ButtonSegment(
                value: LoginMethod.otp,
                icon: Icon(Icons.verified_user_outlined),
                label: Text('Код'),
              ),
            ],
            selected: {_method},
            onSelectionChanged: (selection) {
              setState(() => _method = selection.first);
            },
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: isPassword
                ? Column(
                    key: const ValueKey('password'),
                    children: _passwordFields(),
                  )
                : Column(
                    key: const ValueKey('otp'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _otpFields(),
                  ),
          ),
          const SizedBox(height: 22),
          GradientButton(
            label: isPassword ? 'Войти' : 'Получить код',
            icon: isPassword ? Icons.arrow_forward : Icons.sms_outlined,
            isLoading: _isLoading,
            onPressed: isPassword ? _loginWithPassword : _requestCode,
          ),
          if (isPassword) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegisterScreen(
                      authService: widget.authService,
                    ),
                  ),
                );
              },
              child: const Text('Создать аккаунт с паролем'),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _passwordFields() {
    return [
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.email_outlined, color: AppColors.blush),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
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
    ];
  }

  List<Widget> _otpFields() {
    final isEmail = _channel == OtpChannel.email;

    return [
      SegmentedButton<OtpChannel>(
        segments: const [
          ButtonSegment(
            value: OtpChannel.email,
            icon: Icon(Icons.email_outlined),
            label: Text('Email'),
          ),
          ButtonSegment(
            value: OtpChannel.whatsapp,
            icon: Icon(Icons.chat_outlined),
            label: Text('WhatsApp'),
          ),
        ],
        selected: {_channel},
        onSelectionChanged: (selection) {
          setState(() {
            _channel = selection.first;
            _recipientController.clear();
          });
        },
      ),
      const SizedBox(height: 14),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'patient',
            icon: Icon(Icons.person_outline),
            label: Text('Пациент'),
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
      const SizedBox(height: 14),
      TextField(
        controller: _recipientController,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.phone,
        decoration: InputDecoration(
          labelText: isEmail ? 'Email' : 'Номер WhatsApp',
          hintText: isEmail ? 'name@example.com' : '+77001234567',
          prefixIcon: Icon(
            isEmail ? Icons.email_outlined : Icons.phone_outlined,
            color: AppColors.blush,
          ),
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Для проверки без backend используйте OTP_DELIVERY_MODE=debug.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ];
  }

  void _openApp() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => MainWrapper(authService: widget.authService),
      ),
      (_) => false,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
