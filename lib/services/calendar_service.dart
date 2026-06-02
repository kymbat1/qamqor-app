import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cycle_entry.dart';
import 'auth_service.dart';

class CalendarService {
  final FirebaseFirestore _firestore;
  final AuthService _authService;

  CalendarService({
    FirebaseFirestore? firestore,
    AuthService? authService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authService = authService ?? AuthService();

  Stream<Map<DateTime, CycleEntry>> watchEntries() async* {
    final uid = await _requireUserId();
    yield* _userDoc(uid).snapshots().map((snapshot) {
      return _entriesFromUserData(uid, snapshot.data());
    });
  }

  Future<Map<DateTime, List<CycleEntry>>> fetchEntries() async {
    final uid = await _requireUserId();
    final snapshot = await _userDoc(uid).get();
    final entries = _entriesFromUserData(uid, snapshot.data());

    return entries.map((day, entry) => MapEntry(day, [entry]));
  }

  Future<void> savePeriodEntry({
    required DateTime date,
    String? flow,
    String? mood,
    List<String> symptoms = const [],
    String? note,
  }) async {
    final uid = await _requireUserId();
    final day = CycleEntry.normalizedDay(date);
    final dayKey = CycleEntry.dateKey(day);
    final userRef = _userDoc(uid);
    final snapshot = await userRef.get();
    final currentEntries = _entriesFromUserData(uid, snapshot.data());
    final existingEntry = currentEntries[day];
    final cycleDay = _calculateCycleDay(currentEntries.keys.toList(), day);
    final now = DateTime.now();
    final entry = CycleEntry(
      id: dayKey,
      userId: uid,
      date: day,
      dayKey: dayKey,
      cycleDay: cycleDay,
      isPeriodDay: true,
      flow: flow,
      mood: mood,
      symptoms: symptoms,
      note: (note?.trim().isEmpty ?? true) ? null : note?.trim(),
      createdAt: existingEntry?.createdAt ?? now,
      updatedAt: now,
    );

    currentEntries[day] = entry;
    await _writeEntries(uid, currentEntries);
  }

  Future<void> removeEntry(DateTime date) async {
    final uid = await _requireUserId();
    final userRef = _userDoc(uid);
    final snapshot = await userRef.get();
    final currentEntries = _entriesFromUserData(uid, snapshot.data());

    currentEntries.remove(CycleEntry.normalizedDay(date));
    await _writeEntries(uid, currentEntries);
  }

  Future<void> addEntry(DateTime date) {
    return savePeriodEntry(date: date);
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  Future<String> _requireUserId() async {
    final uid = await _authService.currentUser();
    if (uid == null || uid.isEmpty) {
      throw Exception('user-not-authenticated');
    }
    return uid;
  }

  Map<DateTime, CycleEntry> _entriesFromUserData(
    String uid,
    Map<String, dynamic>? data,
  ) {
    final rawEntries = data?['cycleEntries'];
    if (rawEntries is! Map) {
      return {};
    }

    final entries = <DateTime, CycleEntry>{};
    rawEntries.forEach((key, value) {
      if (value is! Map) {
        return;
      }

      final json = Map<String, dynamic>.from(value);
      json['userId'] ??= uid;
      json['dayKey'] ??= key.toString();

      final entry = CycleEntry.fromJson(json, id: key.toString());
      entries[CycleEntry.normalizedDay(entry.date)] = entry;
    });

    return entries;
  }

  Future<void> _writeEntries(
    String uid,
    Map<DateTime, CycleEntry> entries,
  ) async {
    final cycleEntries = <String, dynamic>{};
    for (final entry in entries.values) {
      cycleEntries[entry.dayKey] = entry.toJson();
    }

    final payload = {
      'cycleEntries': cycleEntries,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _userDoc(uid).update(payload);
    } catch (_) {
      await _userDoc(uid).set(payload, SetOptions(merge: true));
    }
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
}
