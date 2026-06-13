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

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String _role = 'client';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
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

    setState(() => _isLoading = true);
    try {
      await widget.authService.register(name, email, password, role: _role);
      if (!mounted) return;
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
      if (mounted) setState(() => _isLoading = false);
    }
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
    if (text.contains('backend-unavailable')) {
      return 'Backend недоступен. Проверьте, что FastAPI запущен на 8000.';
    }
    return 'Не удалось создать аккаунт';
  }

  @override
  Widget build(BuildContext context) {
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
                const Text(
                  'Создать аккаунт',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Регистрация через Python backend и PostgreSQL. Выберите роль, чтобы открыть нужный интерфейс.',
                  style: TextStyle(
                    color: AppColors.muted,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                SoftCard(
                  radius: 30,
                  child: Column(
                    children: [
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
                ),
                const SizedBox(height: 18),
                GradientButton(
                  label: 'Зарегистрироваться',
                  icon: Icons.person_add_alt_rounded,
                  isLoading: _isLoading,
                  onPressed: _register,
                ),
              ],
            ),
          ),
        ),
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
