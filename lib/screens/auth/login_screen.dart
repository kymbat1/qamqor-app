import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_design.dart';
import '../../utils/auth_validators.dart';
import '../main_wrapper.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;

  const LoginScreen({super.key, required this.authService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
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
    if (password.length < 8) {
      _showMessage('Пароль должен быть минимум 8 символов');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.authService.signIn(email, password);
      if (!mounted) return;
      _openApp();
    } catch (e) {
      if (!mounted) return;
      _showMessage(_messageForError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _messageForError(Object error) {
    final text = error.toString();
    if (text.contains('user-not-found')) {
      return 'Пользователь не найден. Зарегистрируйтесь.';
    }
    if (text.contains('wrong-password') || text.contains('invalid-credential')) {
      return 'Неверный email или пароль.';
    }
    if (text.contains('invalid-email')) return 'Некорректный email.';
    if (text.contains('backend-unavailable')) {
      return 'Backend недоступен. Проверьте, что FastAPI запущен и адрес API указан правильно.';
    }
    return 'Не удалось войти. Проверьте email и пароль.';
  }

  @override
  Widget build(BuildContext context) {
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
                FadeSlideIn(delayMs: 80, child: _buildAuthCard()),
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

  Widget _buildAuthCard() {
    return FrostedPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Вход',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Введите email и пароль. Если аккаунта еще нет, создайте его с подтверждением через код из письма.',
            style: TextStyle(
              color: AppColors.muted,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 22),
          GradientButton(
            label: 'Войти',
            icon: Icons.arrow_forward_rounded,
            isLoading: _isLoading,
            onPressed: _loginWithPassword,
          ),
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
            child: const Text('Создать аккаунт'),
          ),
        ],
      ),
    );
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
