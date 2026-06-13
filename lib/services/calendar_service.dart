import '../models/cycle_entry.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'file_download_service.dart';

class CalendarService {
  final ApiClient _apiClient;
  final AuthService _authService;

  CalendarService({
    ApiClient? apiClient,
    AuthService? authService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authService = authService ?? AuthService();

  Stream<Map<DateTime, CycleEntry>> watchEntries() {
    return Stream.fromFuture(_fetchEntryMap());
  }

  Future<Map<DateTime, List<CycleEntry>>> fetchEntries() async {
    final entries = await _fetchEntryMap();
    return entries.map((day, entry) => MapEntry(day, [entry]));
  }

  Future<void> savePeriodEntry({
    required DateTime date,
    String? flow,
    String? mood,
    List<String> symptoms = const [],
    String? cyclePhase,
    double? weightKg,
    double? heightCm,
    double? temperatureC,
    double? sleepHours,
    int? painLevel,
    int? energyLevel,
    int? stressLevel,
    String? discharge,
    String? libido,
    String? appetite,
    String? activity,
    String? medication,
    String? note,
  }) async {
    await _requireUserId();
    final day = CycleEntry.normalizedDay(date);
    final currentEntries = await _fetchEntryMap();
    final existingEntry = currentEntries[day];
    final cycleDay = _calculateCycleDay(currentEntries.keys.toList(), day);
    final now = DateTime.now();
    final entry = CycleEntry(
      id: existingEntry?.id ?? CycleEntry.dateKey(day),
      userId: existingEntry?.userId,
      date: day,
      cycleDay: cycleDay,
      isPeriodDay: true,
      flow: flow,
      mood: mood,
      symptoms: symptoms,
      cyclePhase: cyclePhase,
      weightKg: weightKg,
      heightCm: heightCm,
      temperatureC: temperatureC,
      sleepHours: sleepHours,
      painLevel: painLevel,
      energyLevel: energyLevel,
      stressLevel: stressLevel,
      discharge: discharge,
      libido: libido,
      appetite: appetite,
      activity: _emptyToNull(activity),
      medication: _emptyToNull(medication),
      note: (note?.trim().isEmpty ?? true) ? null : note?.trim(),
      createdAt: existingEntry?.createdAt ?? now,
      updatedAt: now,
    );

    await _apiClient.post('/cycle', body: entry.toApiJson());
  }

  Future<void> removeEntry(DateTime date) async {
    await _requireUserId();
    final dayKey = CycleEntry.dateKey(CycleEntry.normalizedDay(date));
    await _apiClient.delete('/cycle/$dayKey');
  }

  Future<void> addEntry(DateTime date) {
    return savePeriodEntry(date: date);
  }

  Future<void> downloadYearReportPdf({DateTime? endDate}) async {
    await _requireUserId();
    final end = CycleEntry.normalizedDay(endDate ?? DateTime.now());
    final start = DateTime(end.year - 1, end.month, end.day);
    final query = Uri(queryParameters: {
      'start': CycleEntry.dateKey(start),
      'end': CycleEntry.dateKey(end),
    }).query;
    final bytes = await _apiClient.getBytes('/cycle/report.pdf?$query');
    downloadBytes(
      bytes,
      'cycle-report-${CycleEntry.dateKey(start)}-${CycleEntry.dateKey(end)}.pdf',
      'application/pdf',
    );
  }

  Future<Map<DateTime, CycleEntry>> _fetchEntryMap() async {
    await _requireUserId();
    final response = await _apiClient.getList('/cycle');
    final entries = <DateTime, CycleEntry>{};

    for (final item in response) {
      if (item is! Map) {
        continue;
      }
      final json = Map<String, dynamic>.from(item);
      final entry = CycleEntry.fromJson(json, id: json['id']?.toString());
      entries[CycleEntry.normalizedDay(entry.date)] = entry;
    }

    return entries;
  }

  Future<String> _requireUserId() async {
    final uid = await _authService.currentUser();
    if (uid == null || uid.isEmpty) {
      throw Exception('user-not-authenticated');
    }
    return uid;
  }

  int _calculateCycleDay(List<DateTime> periodDays, DateTime date) {
    final previousPeriodDays = periodDays
        .where((day) => day.isBefore(date))
        .map(CycleEntry.dateKey)
        .toSet();

    var cycleDay = 1;
    var cursor = date.subtract(const Duration(days: 1));

    while (previousPeriodDays.contains(CycleEntry.dateKey(cursor))) {
      cycleDay += 1;
      cursor = cursor.subtract(const Duration(days: 1));
      if (cycleDay >= 10) {
        break;
      }
    }

    return cycleDay;
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
