import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule.dart';
import 'database_helper.dart';

class ScheduleService {
  static final ScheduleService instance = ScheduleService._internal();
  ScheduleService._internal();

  final _uuid = const Uuid();

  Future<Database> get _db => DatabaseHelper.instance.database;

  // ── Anchor Monday (start of rotation timeline) ─────────────────────────

  /// The Monday that defines week index 0 for all rotating schedules.
  Future<DateTime> getScheduleAnchorMonday() async {
    final db = await _db;
    final rows = await db.query(
      'schedule_config',
      where: 'key = ?',
      whereArgs: ['week_a_reference'],
    );

    if (rows.isEmpty) {
      final today = DateTime.now();
      final monday = _mondayOf(today);
      await _storeAnchorMonday(monday);
      return monday;
    }

    final ms = int.parse(rows.first['value'] as String);
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _storeAnchorMonday(DateTime monday) async {
    final db = await _db;
    await db.insert(
      'schedule_config',
      {
        'key': 'week_a_reference',
        'value': monday.millisecondsSinceEpoch.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Whole weeks between [anchorMonday] and the Monday of [date] (can be negative).
  int weeksSinceAnchor(DateTime date, DateTime anchorMonday) {
    final monday = _mondayOf(date);
    final ref = _mondayOf(anchorMonday);
    return monday.difference(ref).inDays ~/ 7;
  }

  /// Which slot (0 … cycleLength-1) [date] falls on in an N-week rotation.
  int cycleSlotForDate(DateTime date, DateTime anchorMonday, int cycleLength) {
    if (cycleLength <= 1) return 0;
    final w = weeksSinceAnchor(date, anchorMonday);
    var mod = w % cycleLength;
    if (mod < 0) mod += cycleLength;
    return mod;
  }

  /// Moves the anchor forward one week (everything shifts in the calendar).
  Future<void> shiftScheduleForwardOneWeek() async {
    final current = await getScheduleAnchorMonday();
    await _storeAnchorMonday(current.add(const Duration(days: 7)));
  }

  /// Backwards compatibility alias.
  Future<void> swapWeekAB() => shiftScheduleForwardOneWeek();

  // ── Schedule entries ───────────────────────────────────────────────────

  Future<List<ScheduleEntry>> getScheduleEntries() async {
    final db = await _db;
    final maps = await db.query(
      'schedule_entries',
      orderBy: 'day_of_week ASC, cycle_length ASC, cycle_index ASC',
    );
    return maps.map(ScheduleEntry.fromMap).toList();
  }

  Future<ScheduleEntry> addScheduleEntry({
    required String templateId,
    required String templateName,
    required int dayOfWeek,
    required int cycleLength,
    required int cycleIndex,
  }) async {
    final len = cycleLength.clamp(1, 8);
    final idx = len <= 1 ? 0 : cycleIndex.clamp(0, len - 1);

    final db = await _db;
    final entry = ScheduleEntry(
      id: _uuid.v4(),
      templateId: templateId,
      templateName: templateName,
      dayOfWeek: dayOfWeek,
      cycleLength: len,
      cycleIndex: idx,
    );
    await db.insert('schedule_entries', entry.toMap());
    return entry;
  }

  Future<void> removeScheduleEntry(String id) async {
    final db = await _db;
    await db.delete('schedule_entries', where: 'id = ?', whereArgs: [id]);
  }

  bool _entryMatchesDate(
    ScheduleEntry entry,
    DateTime date,
    DateTime anchorMonday,
  ) {
    if (entry.dayOfWeek != date.weekday) return false;
    if (entry.cycleLength <= 1) return true;
    return cycleSlotForDate(date, anchorMonday, entry.cycleLength) ==
        entry.cycleIndex;
  }

  // ── Upcoming calculation ───────────────────────────────────────────────

  Future<List<UpcomingWorkout>> getUpcomingWorkouts({int days = 28}) async {
    final entries = await getScheduleEntries();
    if (entries.isEmpty) return [];

    final anchor = await getScheduleAnchorMonday();
    final today = _normalise(DateTime.now());
    final upcoming = <UpcomingWorkout>[];

    for (int i = 0; i < days; i++) {
      final date = today.add(Duration(days: i));

      for (final entry in entries) {
        if (_entryMatchesDate(entry, date, anchor)) {
          upcoming.add(UpcomingWorkout(date: date, entry: entry));
        }
      }
    }

    upcoming.sort((a, b) => a.date.compareTo(b.date));
    return upcoming;
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  DateTime _mondayOf(DateTime date) {
    final d = _normalise(date);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  DateTime _normalise(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
