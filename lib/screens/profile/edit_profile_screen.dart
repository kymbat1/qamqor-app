import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../theme/app_design.dart';

class EditProfileScreen extends StatefulWidget {
  final AuthService authService;

  const EditProfileScreen({super.key, required this.authService});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _cityController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _notesController = TextEditingController();

  File? _imageFile;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = await widget.authService.currentUserData();
    if (!mounted) return;

    setState(() {
      _nameController.text = userData?['name'] ?? '';
      _contactController.text = userData?['email'] ?? userData?['phone'] ?? '';
      _cityController.text = userData?['city'] ?? '';
      _birthDateController.text = userData?['birthDate'] ?? '';
      _notesController.text = userData?['healthNotes'] ?? '';
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 900,
    );

    if (pickedFile != null && mounted) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().length < 2) {
      _showMessage('Введите имя');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.authService.updateCurrentUserProfile({
        'name': _nameController.text,
        'city': _cityController.text,
        'birthDate': _birthDateController.text,
        'healthNotes': _notesController.text,
      });

      if (!mounted) return;
      _showMessage('Профиль сохранен');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Не удалось сохранить профиль');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _cityController.dispose();
    _birthDateController.dispose();
    _notesController.dispose();
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
                  title: 'Редактировать',
                  subtitle: 'Личные данные и заметки',
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(child: _avatarCard()),
                const SizedBox(height: 16),
                FadeSlideIn(delayMs: 70, child: _formCard()),
                const SizedBox(height: 18),
                GradientButton(
                  label: 'Сохранить',
                  icon: Icons.check_rounded,
                  isLoading: _isSaving,
                  onPressed: _saveProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarCard() {
    return SoftCard(
      radius: 30,
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: _imageFile == null ? AppColors.blush : null,
                  image: _imageFile == null
                      ? null
                      : DecorationImage(
                          image: FileImage(_imageFile!),
                          fit: BoxFit.cover,
                        ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: _imageFile == null
                    ? const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 44,
                      )
                    : null,
              ),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.plum,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Твой профиль',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Эти данные помогут врачам и приложению быть точнее.',
                  style: TextStyle(
                    color: AppColors.muted,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    return SoftCard(
      radius: 30,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _field(
            controller: _nameController,
            label: 'Имя и фамилия',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _contactController,
            label: 'Email / WhatsApp',
            icon: Icons.alternate_email_rounded,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _cityController,
            label: 'Город',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _birthDateController,
            label: 'Дата рождения',
            icon: Icons.cake_outlined,
            hint: 'например 12.05.2001',
          ),
          const SizedBox(height: 12),
          _field(
            controller: _notesController,
            label: 'Заметки для себя',
            icon: Icons.notes_rounded,
            minLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool readOnly = false,
    int minLines = 1,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      minLines: minLines,
      maxLines: minLines == 1 ? 1 : 5,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.blush),
        filled: true,
        fillColor: readOnly ? AppColors.lavender.withOpacity(0.55) : Colors.white,
      ),
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
