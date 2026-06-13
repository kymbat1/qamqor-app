import 'package:intl/intl.dart';

import '../models/cycle_entry.dart';
import 'calendar_service.dart';

class CycleContextService {
  final CalendarService _calendarService;

  CycleContextService({CalendarService? calendarService})
      : _calendarService = calendarService ?? CalendarService();

  Future<CycleContext> loadContext({DateTime? now}) async {
    final today = CycleEntry.normalizedDay(now ?? DateTime.now());
    final rawEntries = await _calendarService.fetchEntries();
    final entries = rawEntries.values.expand((items) => items).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final periodDays = entries
        .where((entry) => entry.isPeriodDay)
        .map((entry) => CycleEntry.normalizedDay(entry.date))
        .toSet()
        .toList()
      ..sort();

    final periodStarts = _periodStarts(periodDays);
    final averageCycleLength = _averageCycleLength(periodStarts);
    final latestPeriodDay = _latestPeriodDay(periodDays, today);
    final currentPeriodStart = latestPeriodDay == null
        ? null
        : _periodStartFor(latestPeriodDay, periodDays.toSet());
    final cycleDay = currentPeriodStart == null
        ? null
        : today.difference(currentPeriodStart).inDays + 1;

    return CycleContext(
      today: today,
      entries: entries,
      periodDays: periodDays,
      periodStarts: periodStarts,
      latestPeriodDay: latestPeriodDay,
      currentPeriodStart: currentPeriodStart,
      cycleDay: cycleDay,
      averageCycleLength: averageCycleLength,
    );
  }

  Future<String> buildPromptContext({DateTime? now}) async {
    final context = await loadContext(now: now);
    return context.toPromptText();
  }

  DateTime? _latestPeriodDay(List<DateTime> periodDays, DateTime today) {
    DateTime? latest;
    for (final day in periodDays) {
      if (day.isAfter(today)) {
        continue;
      }
      if (latest == null || day.isAfter(latest)) {
        latest = day;
      }
    }
    return latest;
  }

  DateTime _periodStartFor(DateTime latestDay, Set<DateTime> periodDays) {
    var cursor = latestDay;
    while (periodDays.contains(
      cursor.subtract(const Duration(days: 1)),
    )) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return cursor;
  }

  List<DateTime> _periodStarts(List<DateTime> periodDays) {
    if (periodDays.isEmpty) {
      return [];
    }

    final starts = <DateTime>[periodDays.first];
    for (var i = 1; i < periodDays.length; i++) {
      if (periodDays[i].difference(periodDays[i - 1]).inDays > 1) {
        starts.add(periodDays[i]);
      }
    }
    return starts;
  }

  int _averageCycleLength(List<DateTime> starts) {
    const fallback = 28;
    if (starts.length < 2) {
      return fallback;
    }

    final lengths = <int>[];
    for (var i = 1; i < starts.length; i++) {
      final length = starts[i].difference(starts[i - 1]).inDays;
      if (length >= 20 && length <= 45) {
        lengths.add(length);
      }
    }

    if (lengths.isEmpty) {
      return fallback;
    }

    return (lengths.reduce((a, b) => a + b) / lengths.length).round();
  }
}

class CycleContext {
  final DateTime today;
  final List<CycleEntry> entries;
  final List<DateTime> periodDays;
  final List<DateTime> periodStarts;
  final DateTime? latestPeriodDay;
  final DateTime? currentPeriodStart;
  final int? cycleDay;
  final int averageCycleLength;

  CycleContext({
    required this.today,
    required this.entries,
    required this.periodDays,
    required this.periodStarts,
    required this.latestPeriodDay,
    required this.currentPeriodStart,
    required this.cycleDay,
    required this.averageCycleLength,
  });

  String get phase {
    final day = cycleDay;
    if (day == null || day < 1) {
      return 'фаза неизвестна';
    }
    if (day <= 5) {
      return 'менструальная фаза';
    }
    if (day <= 11) {
      return 'фолликулярная фаза';
    }
    if (day <= 16) {
      return 'овуляторное окно';
    }
    if (day <= averageCycleLength) {
      return 'лютеиновая фаза';
    }
    return 'цикл длиннее обычного или месячные задерживаются';
  }

  bool get hasData => latestPeriodDay != null;

  DateTime? get predictedNextPeriodStart {
    final start = currentPeriodStart;
    if (start == null) {
      return null;
    }
    return start.add(Duration(days: averageCycleLength));
  }

  DateTime? get predictedOvulationDay {
    final start = currentPeriodStart;
    if (start == null) {
      return null;
    }
    return start.add(const Duration(days: 14));
  }

  CycleEntry? get todayEntry {
    for (final entry in entries) {
      if (CycleEntry.dateKey(entry.date) == CycleEntry.dateKey(today)) {
        return entry;
      }
    }
    return null;
  }

  List<CycleEntry> get recentEntries {
    final start = today.subtract(const Duration(days: 7));
    return entries
        .where((entry) {
          final day = CycleEntry.normalizedDay(entry.date);
          return !day.isBefore(start) && !day.isAfter(today);
        })
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  String toPromptText() {
    final dateFormat = DateFormat('d MMMM yyyy', 'ru_RU');
    final shortFormat = DateFormat('d MMM', 'ru_RU');
    final buffer = StringBuffer()
      ..writeln('Сегодня: ${dateFormat.format(today)}.')
      ..writeln('Данные календаря цикла пользователя:');

    if (!hasData) {
      buffer
        ..writeln('- Пользователь еще не отметил месячные в календаре.')
        ..writeln('- Фазу цикла нельзя надежно определить.');
      return buffer.toString();
    }

    buffer
      ..writeln('- Текущая фаза: $phase.')
      ..writeln('- День цикла: ${cycleDay ?? 'неизвестно'}.')
      ..writeln('- Средняя длина цикла: $averageCycleLength дней.')
      ..writeln(
        '- Последнее начало месячных: '
        '${currentPeriodStart == null ? 'неизвестно' : shortFormat.format(currentPeriodStart!)}.',
      )
      ..writeln(
        '- Прогноз следующего начала месячных: '
        '${predictedNextPeriodStart == null ? 'неизвестно' : shortFormat.format(predictedNextPeriodStart!)}.',
      )
      ..writeln(
        '- Примерный день овуляции: '
        '${predictedOvulationDay == null ? 'неизвестно' : shortFormat.format(predictedOvulationDay!)}.',
      );

    final current = todayEntry;
    if (current != null) {
      buffer.writeln('- Сегодня отмечено: ${_entrySummary(current)}.');
    }

    final recent = recentEntries.take(5).toList();
    if (recent.isNotEmpty) {
      buffer.writeln('- Недавние отметки:');
      for (final entry in recent) {
        buffer.writeln(
          '  ${shortFormat.format(entry.date)}: ${_entrySummary(entry)}.',
        );
      }
    }

    return buffer.toString();
  }

  String _entrySummary(CycleEntry entry) {
    final details = <String>[];
    if (entry.isPeriodDay) {
      details.add('месячные');
    }
    if ((entry.flow ?? '').isNotEmpty) {
      details.add('интенсивность: ${entry.flow}');
    }
    if ((entry.mood ?? '').isNotEmpty) {
      details.add('настроение: ${entry.mood}');
    }
    if (entry.symptoms.isNotEmpty) {
      details.add('симптомы: ${entry.symptoms.join(', ')}');
    }
    if ((entry.cyclePhase ?? '').isNotEmpty) {
      details.add('фаза: ${entry.cyclePhase}');
    }
    if (entry.painLevel != null) {
      details.add('боль: ${entry.painLevel}/10');
    }
    if (entry.energyLevel != null) {
      details.add('энергия: ${entry.energyLevel}/5');
    }
    if (entry.stressLevel != null) {
      details.add('стресс: ${entry.stressLevel}/5');
    }
    if (entry.sleepHours != null) {
      details.add('сон: ${entry.sleepHours} ч');
    }
    if (entry.temperatureC != null) {
      details.add('температура: ${entry.temperatureC}');
    }
    if (entry.weightKg != null) {
      details.add('вес: ${entry.weightKg} кг');
    }
    if ((entry.discharge ?? '').isNotEmpty) {
      details.add('выделения: ${entry.discharge}');
    }
    if ((entry.appetite ?? '').isNotEmpty) {
      details.add('аппетит: ${entry.appetite}');
    }
    if ((entry.activity ?? '').isNotEmpty) {
      details.add('активность: ${entry.activity}');
    }
    if ((entry.medication ?? '').isNotEmpty) {
      details.add('лекарства/добавки: ${entry.medication}');
    }
    if ((entry.note ?? '').isNotEmpty) {
      details.add('заметка: ${entry.note}');
    }
    return details.isEmpty ? 'нет деталей' : details.join('; ');
  }
}
