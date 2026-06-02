import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/doctor.dart';
import '../../models/doctor_review.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../services/review_service.dart';
import '../../theme/app_design.dart';
import 'doctor_chat_screen.dart';

class DoctorDetailScreen extends StatefulWidget {
  final Doctor doctor;

  const DoctorDetailScreen({super.key, required this.doctor});

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  final AuthService _authService = AuthService();
  late final AppointmentService _appointmentService =
      AppointmentService(authService: _authService);
  late final ReviewService _reviewService =
      ReviewService(authService: _authService);

  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  bool _isBooking = false;

  final List<String> _times = const [
    '09:00',
    '10:30',
    '12:00',
    '14:30',
    '16:00',
    '17:30',
  ];

  String get _doctorId {
    if (widget.doctor.id.isNotEmpty) return widget.doctor.id;
    return widget.doctor.name.toLowerCase().replaceAll(' ', '-');
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'kk_KZ',
      symbol: '₸',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: GradientPage(
        child: SafeArea(
          child: StreamBuilder<List<DoctorReview>>(
            stream: _reviewService.watchDoctorReviews(_doctorId),
            builder: (context, snapshot) {
              final fallbackReviews = seedDoctorReviews
                  .where((review) => review.doctorId == _doctorId)
                  .toList();
              final reviews = snapshot.hasError
                  ? fallbackReviews
                  : [...snapshot.data ?? <DoctorReview>[], ...fallbackReviews];
              final rating =
                  _reviewService.averageRating(reviews, widget.doctor.rating);

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 116),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _topBar(),
                    const SizedBox(height: 16),
                    FadeSlideIn(child: _doctorHero(rating, reviews.length)),
                    const SizedBox(height: 16),
                    FadeSlideIn(delayMs: 70, child: _aboutCard()),
                    const SizedBox(height: 16),
                    FadeSlideIn(delayMs: 110, child: _locationCard()),
                    const SizedBox(height: 16),
                    FadeSlideIn(delayMs: 150, child: _scheduleCard()),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delayMs: 190,
                      child: _reviewsCard(reviews, snapshot.hasError),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: FrostedPanel(
          radius: 26,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Стоимость',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _formatCurrency(widget.doctor.consultationFee),
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GradientButton(
                  label: 'Записаться',
                  icon: Icons.calendar_month_rounded,
                  isLoading: _isBooking,
                  onPressed:
                      _selectedTime == null || _isBooking ? null : _bookAppointment,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const Spacer(),
        IconButton.filledTonal(
          tooltip: 'Чат',
          onPressed: _openPatientChat,
          icon: const Icon(Icons.chat_bubble_outline_rounded),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Отзыв',
          onPressed: _showReviewSheet,
          icon: const Icon(Icons.rate_review_outlined),
        ),
      ],
    );
  }

  Widget _doctorHero(double rating, int reviewsCount) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppShadows.floating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _doctorAvatar(size: 78, textColor: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.doctor.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.doctor.specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _heroPill(Icons.star_rounded, rating.toStringAsFixed(1)),
              const SizedBox(width: 8),
              _heroPill(Icons.reviews_rounded, '$reviewsCount отзывов'),
              const SizedBox(width: 8),
              _heroPill(
                Icons.work_outline_rounded,
                '${widget.doctor.yearsOfExperience} лет',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _doctorAvatar({
    double size = 76,
    Color textColor = AppColors.blush,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(textColor == Colors.white ? 0.22 : 1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Center(
        child: Text(
          widget.doctor.initials,
          style: TextStyle(
            color: textColor,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _heroPill(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aboutCard() {
    return SoftCard(
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'О враче',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.doctor.description.isEmpty
                ? 'Врач пока не добавил описание.'
                : widget.doctor.description,
            style: const TextStyle(
              color: AppColors.muted,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _infoRow(Icons.local_hospital_outlined, widget.doctor.hospital),
          _infoRow(Icons.school_outlined, widget.doctor.university),
        ],
      ),
    );
  }

  Widget _locationCard() {
    return SoftCard(
      radius: 30,
      color: AppColors.lavender,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.place_rounded, color: AppColors.blush),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.doctor.city,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.doctor.address.isEmpty
                      ? widget.doctor.hospital
                      : '${widget.doctor.hospital}, ${widget.doctor.address}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Показать на карте',
            onPressed: _showClinicMap,
            icon: const Icon(Icons.map_outlined, color: AppColors.plum),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.blush, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
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

  Widget _scheduleCard() {
    final today = DateTime.now();
    return SoftCard(
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Выберите время',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Свободные окна обновлены от сегодняшней даты.',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 14,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final date = today.add(Duration(days: index));
                final selected = _sameDate(date, _selectedDate);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      _selectedTime = null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 66,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.blush : AppColors.lavender,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected ? AppColors.blush : Colors.white,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          index == 0
                              ? 'Сегодня'
                              : index == 1
                                  ? 'Завтра'
                                  : DateFormat('EEE', 'ru_RU').format(date),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.muted,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          DateFormat('d').format(date),
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _times.map((time) {
              final selected = time == _selectedTime;
              return GestureDetector(
                onTap: () => setState(() => _selectedTime = time),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.blush : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected ? AppColors.blush : AppColors.lavender,
                    ),
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.plum,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _reviewsCard(List<DoctorReview> reviews, bool hasError) {
    return SoftCard(
      radius: 30,
      color: AppColors.mint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Отзывы',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showReviewSheet,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Написать'),
              ),
            ],
          ),
          if (hasError)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Сейчас показаны примеры отзывов. Проверьте правила Firebase для doctor_reviews.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          if (reviews.isEmpty)
            const Text(
              'Отзывов пока нет. Можно стать первой, кто поделится впечатлением.',
              style: TextStyle(color: AppColors.muted, height: 1.35),
            )
          else
            ...reviews.take(4).map(_reviewTile),
        ],
      ),
    );
  }

  Widget _reviewTile(DoctorReview review) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_circle_rounded, color: AppColors.blush),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.patientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              Text(
                review.rating.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.text,
            style: const TextStyle(
              color: AppColors.muted,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPatientChat() async {
    final patientId = await _authService.currentUser();
    if (patientId == null || patientId.isEmpty) {
      _showMessage('Сначала войдите в аккаунт');
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorChatScreen(
          chatId: '${_doctorId}_$patientId',
          title: widget.doctor.name,
          senderRole: 'patient',
          authService: _authService,
        ),
      ),
    );
  }

  Future<void> _bookAppointment() async {
    if (_selectedTime == null) return;

    final parts = _selectedTime!.split(':');
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    setState(() => _isBooking = true);
    try {
      await _appointmentService.createAppointment(
        doctor: widget.doctor,
        dateTime: dateTime,
      );
      if (!mounted) return;
      final formattedDate = DateFormat('d MMMM', 'ru_RU').format(dateTime);
      _showMessage('Запись создана на $formattedDate в $_selectedTime');
      await _openPatientChat();
    } catch (_) {
      if (!mounted) return;
      _showMessage('Не удалось создать запись. Проверьте вход и правила Firebase.');
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Future<void> _showReviewSheet() async {
    final result = await showModalBottomSheet<_ReviewResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ReviewSheet(),
    );

    if (result == null) return;

    try {
      await _reviewService.addReview(
        doctorId: _doctorId,
        rating: result.rating,
        text: result.text,
      );
      if (!mounted) return;
      _showMessage('Спасибо, отзыв добавлен');
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Не удалось сохранить отзыв. Проверьте вход и правила Firebase.',
      );
    }
  }

  void _showClinicMap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: AppColors.lavender,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const Text(
                  'Карта клиники',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: SizedBox(
                    height: 240,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DetailMapPainter(),
                            child: Container(color: const Color(0xFFFFEEF7)),
                          ),
                        ),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.blush,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: AppShadows.soft,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_hospital_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Клиника',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.doctor.hospital,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.doctor.city}, ${widget.doctor.address}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet();

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final TextEditingController _controller = TextEditingController();
  double _rating = 5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.lavender,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const Text(
                'Ваш отзыв',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: List.generate(5, (index) {
                  final filled = index < _rating.round();
                  return IconButton(
                    onPressed: () => setState(() => _rating = index + 1),
                    icon: Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Расскажите о приеме',
                  hintText: 'Что понравилось, насколько было комфортно?',
                ),
              ),
              const SizedBox(height: 18),
              GradientButton(
                label: 'Опубликовать',
                icon: Icons.send_rounded,
                onPressed: () {
                  final text = _controller.text.trim();
                  if (text.length < 4) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Напишите хотя бы пару слов'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(
                    context,
                    _ReviewResult(rating: _rating, text: text),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewResult {
  final double rating;
  final String text;

  const _ReviewResult({
    required this.rating,
    required this.text,
  });
}

class _DetailMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final smallRoadPaint = Paint()
      ..color = Colors.white.withOpacity(0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final parkPaint = Paint()
      ..color = const Color(0xFFE9F8F1)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.12, 92, 52),
        const Radius.circular(22),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62, size.height * 0.62, 92, 48),
        const Radius.circular(22),
      ),
      parkPaint,
    );

    final mainPath = Path()
      ..moveTo(-20, size.height * 0.24)
      ..quadraticBezierTo(
        size.width * 0.38,
        size.height * 0.04,
        size.width * 0.54,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.75,
        size.width + 20,
        size.height * 0.58,
      );
    canvas.drawPath(mainPath, roadPaint);

    final crossPath = Path()
      ..moveTo(size.width * 0.12, size.height + 10)
      ..quadraticBezierTo(
        size.width * 0.44,
        size.height * 0.58,
        size.width * 0.78,
        -10,
      );
    canvas.drawPath(crossPath, smallRoadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
