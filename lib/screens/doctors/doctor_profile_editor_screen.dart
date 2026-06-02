import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_design.dart';

class DoctorProfileEditorScreen extends StatefulWidget {
  final AuthService authService;

  const DoctorProfileEditorScreen({super.key, required this.authService});

  @override
  State<DoctorProfileEditorScreen> createState() =>
      _DoctorProfileEditorScreenState();
}

class _DoctorProfileEditorScreenState extends State<DoctorProfileEditorScreen> {
  final _nameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _universityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _feeController = TextEditingController();
  final _experienceController = TextEditingController();

  bool _isOnline = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    _hospitalController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _universityController.dispose();
    _descriptionController.dispose();
    _feeController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = await widget.authService.currentUser();
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('doctor_profiles')
        .doc(uid)
        .get();
    final data = doc.data() ?? {};

    if (!mounted) return;
    setState(() {
      _nameController.text = data['name'] ?? '';
      _specialtyController.text = data['specialty'] ?? '';
      _hospitalController.text = data['hospital'] ?? '';
      _cityController.text = data['city'] ?? '';
      _addressController.text = data['address'] ?? '';
      _universityController.text = data['university'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _feeController.text = '${data['consultationFee'] ?? ''}';
      _experienceController.text = '${data['yearsOfExperience'] ?? ''}';
      _isOnline = data['isOnline'] ?? true;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final uid = await widget.authService.currentUser();
    if (uid == null) return;

    if (_nameController.text.trim().length < 2 ||
        _specialtyController.text.trim().isEmpty ||
        _hospitalController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty) {
      _showMessage('Заполните имя, специализацию, клинику и город');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final point = _cityPoint(_cityController.text.trim());
      final profile = {
        'userId': uid,
        'name': _nameController.text.trim(),
        'specialty': _specialtyController.text.trim(),
        'hospital': _hospitalController.text.trim(),
        'city': _cityController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': point.$1,
        'longitude': point.$2,
        'university': _universityController.text.trim(),
        'description': _descriptionController.text.trim(),
        'consultationFee': double.tryParse(_feeController.text.trim()) ?? 0,
        'yearsOfExperience': int.tryParse(_experienceController.text.trim()) ?? 0,
        'isOnline': _isOnline,
        'gender': 'female',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('doctor_profiles')
          .doc(uid)
          .set(profile, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'role': 'doctor',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      _showMessage('Профиль врача сохранен');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Не удалось сохранить профиль');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  (double, double) _cityPoint(String city) {
    final value = city.toLowerCase();
    if (value.contains('астана')) return (51.169392, 71.449074);
    if (value.contains('шымкент')) return (42.341684, 69.590101);
    return (43.238949, 76.889709);
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
                _header(),
                const SizedBox(height: 18),
                FadeSlideIn(child: _statusCard()),
                const SizedBox(height: 16),
                FadeSlideIn(delayMs: 80, child: _formCard()),
                const SizedBox(height: 18),
                GradientButton(
                  label: 'Сохранить',
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

  Widget _header() {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Профиль врача',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Эти данные увидят пациенты при записи',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppShadows.floating,
      ),
      child: SwitchListTile(
        value: _isOnline,
        onChanged: (value) => setState(() => _isOnline = value),
        contentPadding: EdgeInsets.zero,
        activeColor: Colors.white,
        title: const Text(
          'Принимать онлайн',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: const Text(
          'Пациенты будут видеть этот статус в разделе записи',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _formCard() {
    return SoftCard(
      radius: 30,
      child: Column(
        children: [
          _field(_nameController, 'Имя и фамилия', Icons.person_outline_rounded),
          _field(
            _specialtyController,
            'Специализация',
            Icons.medical_services_outlined,
          ),
          _field(
            _hospitalController,
            'Клиника',
            Icons.local_hospital_outlined,
          ),
          _field(_cityController, 'Город', Icons.location_city_rounded),
          _field(_addressController, 'Адрес клиники', Icons.place_outlined),
          _field(_universityController, 'Образование', Icons.school_outlined),
          _field(
            _experienceController,
            'Стаж, лет',
            Icons.work_outline_rounded,
            keyboardType: TextInputType.number,
          ),
          _field(
            _feeController,
            'Стоимость консультации',
            Icons.payments_outlined,
            keyboardType: TextInputType.number,
          ),
          _field(
            _descriptionController,
            'Описание',
            Icons.notes_rounded,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.blush),
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
