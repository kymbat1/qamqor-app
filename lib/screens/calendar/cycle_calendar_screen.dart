import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/cycle_entry.dart';
import '../../services/calendar_service.dart';
import '../../theme/app_design.dart';

class CycleCalendarScreen extends StatelessWidget {
  const CycleCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: CycleCalendarContent(),
    );
  }
}

class CycleCalendarContent extends StatefulWidget {
  const CycleCalendarContent({super.key});

  @override
  State<CycleCalendarContent> createState() => _CycleCalendarContentState();
}

class _CycleCalendarContentState extends State<CycleCalendarContent> {
  final CalendarService _calendarService = CalendarService();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isSaving = false;

  static const List<String> _flowOptions = [
    'Легкие',
    'Средние',
    'Обильные',
  ];

  static const List<String> _moodOptions = [
    'Спокойно',
    'Нежно',
    'Устала',
    'Тревожно',
    'Энергично',
  ];

  static const List<String> _symptomOptions = [
    'Боль',
    'Спазмы',
    'Головная боль',
    'Тошнота',
    'Вздутие',
    'Акне',
    'Сонливость',
    'Перепады настроения',
  ];

  @override
  Widget build(BuildContext context) {
    return GradientPage(
      child: SafeArea(
        child: StreamBuilder<Map<DateTime, CycleEntry>>(
          stream: _calendarService.watchEntries(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorState(
                message: _calendarErrorText(snapshot.error),
                onRetry: () => setState(() {}),
              );
            }

            final entries = snapshot.data ?? {};
            final periodDays = _periodDays(entries);
            final stats = _CycleStats.fromEntries(periodDays);
            final selectedEntry = _entryForDay(entries, _selectedDay);

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeSlideIn(
                        child: _Header(
                          title: 'Календарь цикла',
                          subtitle: _selectedDayLabel(_selectedDay),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FadeSlideIn(
                        delayMs: 70,
                        child: _CycleHero(stats: stats),
                      ),
                      const SizedBox(height: 18),
                      FadeSlideIn(
                        delayMs: 120,
                        child: _CalendarCard(
                          focusedDay: _focusedDay,
                          selectedDay: _selectedDay,
                          entries: entries,
                          stats: stats,
                          onPageChanged: (day) {
                            setState(() => _focusedDay = day);
                          },
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = CycleEntry.normalizedDay(selectedDay);
                              _focusedDay = focusedDay;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      FadeSlideIn(
                        delayMs: 170,
                        child: _SelectedDayCard(
                          selectedDay: _selectedDay,
                          entry: selectedEntry,
                          isSaving: _isSaving,
                          onMark: () => _openEntrySheet(selectedEntry),
                          onRemove: selectedEntry == null
                              ? null
                              : () => _removeEntry(_selectedDay),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FadeSlideIn(
                        delayMs: 220,
                        child: _InsightsGrid(stats: stats),
                      ),
                    ],
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const Center(child: CircularProgressIndicator()),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openEntrySheet(CycleEntry? entry) async {
    final result = await showModalBottomSheet<_EntryFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EntrySheet(
          selectedDay: _selectedDay,
          entry: entry,
          flowOptions: _flowOptions,
          moodOptions: _moodOptions,
          symptomOptions: _symptomOptions,
        );
      },
    );

    if (result == null) {
      return;
    }

    await _saveEntry(result);
  }

  Future<void> _saveEntry(_EntryFormResult result) async {
    setState(() => _isSaving = true);
    try {
      await _calendarService.savePeriodEntry(
        date: _selectedDay,
        flow: result.flow,
        mood: result.mood,
        symptoms: result.symptoms,
        note: result.note,
      );
      _showSnack('День цикла сохранен');
    } catch (e) {
      _showSnack(_calendarErrorText(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _removeEntry(DateTime date) async {
    setState(() => _isSaving = true);
    try {
      await _calendarService.removeEntry(date);
      _showSnack('Отметка удалена');
    } catch (e) {
      _showSnack(_calendarErrorText(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AppColors.plum,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<DateTime> _periodDays(Map<DateTime, CycleEntry> entries) {
    final days = entries.entries
        .where((entry) => entry.value.isPeriodDay)
        .map((entry) => CycleEntry.normalizedDay(entry.key))
        .toList()
      ..sort();
    return days;
  }

  CycleEntry? _entryForDay(Map<DateTime, CycleEntry> entries, DateTime day) {
    return entries[CycleEntry.normalizedDay(day)];
  }

  String _selectedDayLabel(DateTime day) {
    return DateFormat('d MMMM', 'ru_RU').format(day);
  }

  String _calendarErrorText(Object? error) {
    final text = error.toString();
    if (text.contains('user-not-authenticated')) {
      return 'Войдите в аккаунт, чтобы вести календарь';
    }
    if (text.contains('permission-denied')) {
      return 'Firebase не разрешил сохранить данные. Проверьте правила Firestore.';
    }
    return 'Не получилось загрузить календарь. Попробуйте еще раз.';
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            shape: BoxShape.circle,
            boxShadow: AppShadows.soft,
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.blush,
          ),
        ),
      ],
    );
  }
}

class _CycleHero extends StatelessWidget {
  final _CycleStats stats;

  const _CycleHero({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.blush.withOpacity(0.32),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -16,
            child: _PulseOrb(size: 120, opacity: 0.16),
          ),
          Positioned(
            right: 52,
            bottom: -34,
            child: _PulseOrb(size: 82, opacity: 0.12),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Сегодня',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stats.cycleDayText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 58,
                      height: 0.95,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      stats.hasData ? 'день цикла' : 'нет данных',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: stats.progress,
                  backgroundColor: Colors.white.withOpacity(0.28),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _HeroMeta(
                      icon: Icons.water_drop_rounded,
                      label: 'Следующие',
                      value: stats.nextPeriodText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HeroMeta(
                      icon: Icons.spa_rounded,
                      label: 'Окно',
                      value: stats.fertileWindowText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulseOrb extends StatelessWidget {
  final double size;
  final double opacity;

  const _PulseOrb({
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1.08),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroMeta({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
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
}

class _CalendarCard extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final Map<DateTime, CycleEntry> entries;
  final _CycleStats stats;
  final void Function(DateTime focusedDay) onPageChanged;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;

  const _CalendarCard({
    required this.focusedDay,
    required this.selectedDay,
    required this.entries,
    required this.stats,
    required this.onPageChanged,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      radius: 30,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      child: TableCalendar<CycleEntry>(
        locale: 'ru_RU',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) => isSameDay(day, selectedDay),
        onPageChanged: onPageChanged,
        onDaySelected: onDaySelected,
        startingDayOfWeek: StartingDayOfWeek.monday,
        availableGestures: AvailableGestures.horizontalSwipe,
        calendarFormat: CalendarFormat.month,
        rowHeight: 48,
        daysOfWeekHeight: 28,
        eventLoader: (day) {
          final entry = entries[CycleEntry.normalizedDay(day)];
          return entry == null ? [] : [entry];
        },
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: AppColors.plum,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: AppColors.plum,
          ),
          titleTextStyle: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
          weekendStyle: TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: true,
          markersMaxCount: 0,
          cellMargin: EdgeInsets.all(3),
        ),
        calendarBuilders: CalendarBuilders<CycleEntry>(
          defaultBuilder: (context, day, _) {
            return _DayCell(
              day: day,
              entry: entries[CycleEntry.normalizedDay(day)],
              isFertile: stats.isFertileDay(day),
            );
          },
          todayBuilder: (context, day, _) {
            return _DayCell(
              day: day,
              entry: entries[CycleEntry.normalizedDay(day)],
              isToday: true,
              isFertile: stats.isFertileDay(day),
            );
          },
          selectedBuilder: (context, day, _) {
            return _DayCell(
              day: day,
              entry: entries[CycleEntry.normalizedDay(day)],
              isSelected: true,
              isToday: isSameDay(day, DateTime.now()),
              isFertile: stats.isFertileDay(day),
            );
          },
          outsideBuilder: (context, day, _) {
            return Opacity(
              opacity: 0.34,
              child: _DayCell(
                day: day,
                entry: entries[CycleEntry.normalizedDay(day)],
                isFertile: stats.isFertileDay(day),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final CycleEntry? entry;
  final bool isSelected;
  final bool isToday;
  final bool isFertile;

  const _DayCell({
    required this.day,
    this.entry,
    this.isSelected = false,
    this.isToday = false,
    this.isFertile = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPeriod = entry?.isPeriodDay ?? false;
    final hasNote = entry?.note?.isNotEmpty ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isSelected || isPeriod
            ? AppColors.blush
            : isFertile
                ? AppColors.mint
                : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? AppColors.blush
              : isFertile
                  ? const Color(0xFFBFE9D6)
                  : Colors.transparent,
          width: isToday ? 1.6 : 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              color: isSelected || isPeriod ? Colors.white : AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (hasNote)
            Positioned(
              bottom: 5,
              child: Container(
                height: 4,
                width: 4,
                decoration: BoxDecoration(
                  color: isSelected || isPeriod ? Colors.white : AppColors.blush,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectedDayCard extends StatelessWidget {
  final DateTime selectedDay;
  final CycleEntry? entry;
  final bool isSaving;
  final VoidCallback onMark;
  final VoidCallback? onRemove;

  const _SelectedDayCard({
    required this.selectedDay,
    required this.entry,
    required this.isSaving,
    required this.onMark,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isMarked = entry?.isPeriodDay ?? false;

    return SoftCard(
      radius: 30,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: isMarked ? AppColors.blush : AppColors.lavender,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isMarked
                      ? Icons.water_drop_rounded
                      : Icons.calendar_today_rounded,
                  color: isMarked ? Colors.white : AppColors.plum,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('d MMMM, EEEE', 'ru_RU').format(selectedDay),
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isMarked
                          ? 'Месячные отмечены'
                          : 'Данных на этот день пока нет',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isMarked) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (entry?.flow != null) _InfoChip('Выделения: ${entry!.flow}'),
                if (entry?.mood != null) _InfoChip('Настроение: ${entry!.mood}'),
                ...?entry?.symptoms.map(_InfoChip.new),
              ],
            ),
            if (entry?.note?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Text(
                entry!.note!,
                style: const TextStyle(
                  color: AppColors.ink,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  label: isMarked ? 'Изменить' : 'Отметить',
                  icon: isMarked ? Icons.edit_rounded : Icons.add_rounded,
                  isLoading: isSaving,
                  onPressed: onMark,
                ),
              ),
              if (isMarked) ...[
                const SizedBox(width: 10),
                _RoundIconButton(
                  icon: Icons.delete_outline_rounded,
                  onPressed: isSaving ? null : onRemove,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.lavender.withOpacity(0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.plum,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: onPressed == null ? 0.45 : 1,
        child: Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            color: AppColors.lavender,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: AppColors.plum),
        ),
      ),
    );
  }
}

class _InsightsGrid extends StatelessWidget {
  final _CycleStats stats;

  const _InsightsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Подсказки',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                icon: Icons.favorite_rounded,
                title: 'Овуляция',
                value: stats.ovulationText,
                color: AppColors.sky,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InsightCard(
                icon: Icons.timeline_rounded,
                title: 'Длина цикла',
                value: stats.averageCycleText,
                color: AppColors.mint,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      radius: 24,
      color: color,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.plum, size: 24),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              height: 1.08,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntrySheet extends StatefulWidget {
  final DateTime selectedDay;
  final CycleEntry? entry;
  final List<String> flowOptions;
  final List<String> moodOptions;
  final List<String> symptomOptions;

  const _EntrySheet({
    required this.selectedDay,
    required this.entry,
    required this.flowOptions,
    required this.moodOptions,
    required this.symptomOptions,
  });

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late String _flow;
  late String _mood;
  late Set<String> _symptoms;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _flow = widget.entry?.flow ?? widget.flowOptions[1];
    _mood = widget.entry?.mood ?? widget.moodOptions.first;
    _symptoms = {...?widget.entry?.symptoms};
    _noteController = TextEditingController(text: widget.entry?.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 5,
                  width: 42,
                  decoration: BoxDecoration(
                    color: AppColors.lavender,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                DateFormat('d MMMM', 'ru_RU').format(widget.selectedDay),
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Отметка месячных и самочувствия',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _SheetSection(
                title: 'Интенсивность',
                child: _ChoiceWrap(
                  options: widget.flowOptions,
                  selected: {_flow},
                  onTap: (value) => setState(() => _flow = value),
                ),
              ),
              _SheetSection(
                title: 'Настроение',
                child: _ChoiceWrap(
                  options: widget.moodOptions,
                  selected: {_mood},
                  onTap: (value) => setState(() => _mood = value),
                ),
              ),
              _SheetSection(
                title: 'Симптомы',
                child: _ChoiceWrap(
                  options: widget.symptomOptions,
                  selected: _symptoms,
                  onTap: (value) {
                    setState(() {
                      if (_symptoms.contains(value)) {
                        _symptoms.remove(value);
                      } else {
                        _symptoms.add(value);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Заметка',
                  hintText: 'Например: боль была сильнее вечером',
                ),
              ),
              const SizedBox(height: 18),
              GradientButton(
                label: 'Сохранить день',
                icon: Icons.check_rounded,
                onPressed: () {
                  Navigator.pop(
                    context,
                    _EntryFormResult(
                      flow: _flow,
                      mood: _mood,
                      symptoms: _symptoms.toList()..sort(),
                      note: _noteController.text,
                    ),
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

class _SheetSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SheetSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  const _ChoiceWrap({
    required this.options,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return GestureDetector(
          onTap: () => onTap(option),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.blush : AppColors.lavender.withOpacity(0.62),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              option,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.plum,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _EntryFormResult {
  final String flow;
  final String mood;
  final List<String> symptoms;
  final String note;

  _EntryFormResult({
    required this.flow,
    required this.mood,
    required this.symptoms,
    required this.note,
  });
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SoftCard(
          radius: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.blush,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Повторить',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleStats {
  static const int defaultCycleLength = 28;
  final List<DateTime> periodDays;
  final DateTime today;
  final DateTime? latestPeriodDay;
  final int averageCycleLength;

  _CycleStats({
    required this.periodDays,
    required this.today,
    required this.latestPeriodDay,
    required this.averageCycleLength,
  });

  factory _CycleStats.fromEntries(List<DateTime> periodDays) {
    final normalizedToday = CycleEntry.normalizedDay(DateTime.now());
    final starts = _periodStarts(periodDays);
    DateTime? latest;
    for (final day in periodDays) {
      if (day.isAfter(normalizedToday)) {
        continue;
      }
      if (latest == null || day.isAfter(latest)) {
        latest = day;
      }
    }

    return _CycleStats(
      periodDays: periodDays,
      today: normalizedToday,
      latestPeriodDay: latest,
      averageCycleLength: _averageCycleLength(starts),
    );
  }

  bool get hasData => latestPeriodDay != null;

  int? get cycleDay {
    if (latestPeriodDay == null) {
      return null;
    }
    return today.difference(latestPeriodDay!).inDays + 1;
  }

  String get cycleDayText => cycleDay?.toString() ?? '--';

  double get progress {
    if (cycleDay == null) {
      return 0;
    }
    return (cycleDay! / averageCycleLength).clamp(0.0, 1.0).toDouble();
  }

  DateTime? get nextPeriodStart {
    if (latestPeriodDay == null) {
      return null;
    }
    return latestPeriodDay!.add(Duration(days: averageCycleLength));
  }

  DateTime? get ovulationDay {
    if (latestPeriodDay == null) {
      return null;
    }
    return latestPeriodDay!.add(const Duration(days: 14));
  }

  DateTime? get fertileStart {
    if (latestPeriodDay == null) {
      return null;
    }
    return latestPeriodDay!.add(const Duration(days: 11));
  }

  DateTime? get fertileEnd {
    if (latestPeriodDay == null) {
      return null;
    }
    return latestPeriodDay!.add(const Duration(days: 16));
  }

  String get nextPeriodText {
    final date = nextPeriodStart;
    return date == null ? 'Отметь 1 день' : DateFormat('d MMM', 'ru_RU').format(date);
  }

  String get fertileWindowText {
    if (fertileStart == null || fertileEnd == null) {
      return 'после отметки';
    }
    return '${DateFormat('d MMM', 'ru_RU').format(fertileStart!)} - ${DateFormat('d MMM', 'ru_RU').format(fertileEnd!)}';
  }

  String get ovulationText {
    final date = ovulationDay;
    return date == null ? 'нет данных' : DateFormat('d MMMM', 'ru_RU').format(date);
  }

  String get averageCycleText => '$averageCycleLength дней';

  bool isFertileDay(DateTime day) {
    if (fertileStart == null || fertileEnd == null) {
      return false;
    }
    final normalized = CycleEntry.normalizedDay(day);
    return !normalized.isBefore(fertileStart!) && !normalized.isAfter(fertileEnd!);
  }

  static List<DateTime> _periodStarts(List<DateTime> periodDays) {
    if (periodDays.isEmpty) {
      return [];
    }

    final sorted = [...periodDays]..sort();
    final starts = <DateTime>[sorted.first];

    for (var i = 1; i < sorted.length; i++) {
      final day = sorted[i];
      final previous = sorted[i - 1];
      if (day.difference(previous).inDays > 1) {
        starts.add(day);
      }
    }
    return starts;
  }

  static int _averageCycleLength(List<DateTime> starts) {
    if (starts.length < 2) {
      return defaultCycleLength;
    }

    final lengths = <int>[];
    for (var i = 1; i < starts.length; i++) {
      final diff = starts[i].difference(starts[i - 1]).inDays;
      if (diff >= 20 && diff <= 45) {
        lengths.add(diff);
      }
    }

    if (lengths.isEmpty) {
      return defaultCycleLength;
    }

    final sum = lengths.reduce((a, b) => a + b);
    return (sum / lengths.length).round();
  }
}
