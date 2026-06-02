import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/cycle_entry.dart';
import '../../services/calendar_service.dart';
import '../../theme/app_design.dart';

class ChartReportScreen extends StatelessWidget {
  const ChartReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: GradientPage(
        child: SafeArea(
          child: StreamBuilder<Map<DateTime, CycleEntry>>(
            stream: CalendarService().watchEntries(),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? {};
              final report = _CycleReport.fromEntries(entries.values.toList());

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      title: 'Графики',
                      subtitle: 'Отчеты по циклу',
                      onBack: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 18),
                    FadeSlideIn(child: _summary(report)),
                    const SizedBox(height: 16),
                    FadeSlideIn(delayMs: 80, child: _cycleBars(report)),
                    const SizedBox(height: 16),
                    FadeSlideIn(delayMs: 130, child: _symptoms(report)),
                    if (snapshot.connectionState == ConnectionState.waiting) ...[
                      const SizedBox(height: 20),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _summary(_CycleReport report) {
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
          const Text(
            'Сводка',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _heroMetric(report.totalDays.toString(), 'отметок'),
              _heroMetric(report.averagePeriodLengthText, 'длина'),
              _heroMetric(report.lastPeriodText, 'последний'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cycleBars(_CycleReport report) {
    return SoftCard(
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Последние циклы',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          if (report.periodGroups.isEmpty)
            const _EmptyHint(
              icon: Icons.bar_chart_rounded,
              text: 'Отметь месячные в календаре, и здесь появится история.',
            )
          else
            ...report.periodGroups.take(6).map((group) {
              final length = group.length.clamp(1, 8).toInt();
              return Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  children: [
                    SizedBox(
                      width: 78,
                      child: Text(
                        DateFormat('d MMM', 'ru_RU').format(group.first),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 12,
                          value: (length / 8).toDouble(),
                          color: AppColors.blush,
                          backgroundColor: AppColors.lavender,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$length дн.',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _symptoms(_CycleReport report) {
    return SoftCard(
      radius: 30,
      color: AppColors.mint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Частые симптомы',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          if (report.symptoms.isEmpty)
            const _EmptyHint(
              icon: Icons.spa_rounded,
              text: 'Добавляй симптомы при отметке дня, чтобы видеть повторения.',
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: report.symptoms.entries.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.78),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${item.key} · ${item.value}',
                    style: const TextStyle(
                      color: AppColors.plum,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _CycleReport {
  final List<CycleEntry> entries;
  final List<List<DateTime>> periodGroups;
  final Map<String, int> symptoms;

  _CycleReport({
    required this.entries,
    required this.periodGroups,
    required this.symptoms,
  });

  factory _CycleReport.fromEntries(List<CycleEntry> entries) {
    final periodDays = entries
        .where((entry) => entry.isPeriodDay)
        .map((entry) => CycleEntry.normalizedDay(entry.date))
        .toList()
      ..sort();

    final groups = <List<DateTime>>[];
    for (final day in periodDays) {
      if (groups.isEmpty || day.difference(groups.last.last).inDays > 1) {
        groups.add([day]);
      } else {
        groups.last.add(day);
      }
    }

    final symptoms = <String, int>{};
    for (final entry in entries) {
      for (final symptom in entry.symptoms) {
        symptoms[symptom] = (symptoms[symptom] ?? 0) + 1;
      }
    }

    final sortedSymptoms = Map.fromEntries(
      symptoms.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );

    return _CycleReport(
      entries: entries,
      periodGroups: groups.reversed.toList(),
      symptoms: sortedSymptoms,
    );
  }

  int get totalDays => entries.where((entry) => entry.isPeriodDay).length;

  String get averagePeriodLengthText {
    if (periodGroups.isEmpty) {
      return '--';
    }
    final total = periodGroups.fold<int>(0, (sum, group) => sum + group.length);
    return '${(total / periodGroups.length).round()} дн.';
  }

  String get lastPeriodText {
    if (periodGroups.isEmpty) {
      return '--';
    }
    return DateFormat('d MMM', 'ru_RU').format(periodGroups.first.first);
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.blush),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
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
