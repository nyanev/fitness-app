/// Legacy DB values for migration only.
enum _LegacyWeekPattern {
  every,
  weekA,
  weekB;

  static _LegacyWeekPattern? fromDb(String? value) => switch (value) {
        'every' => _LegacyWeekPattern.every,
        'week_a' => _LegacyWeekPattern.weekA,
        'week_b' => _LegacyWeekPattern.weekB,
        _ => null,
      };
}

class ScheduleEntry {
  final String id;
  final String templateId;
  final String templateName;

  /// ISO weekday: 1=Monday … 7=Sunday (matches [DateTime.weekday]).
  final int dayOfWeek;

  /// `1` = repeats every calendar week. `2`–`8` = only on one slot in an
  /// N-week rotation (see [cycleIndex]).
  final int cycleLength;

  /// 0-based position inside the rotation (`0 … cycleLength - 1`).
  final int cycleIndex;

  const ScheduleEntry({
    required this.id,
    required this.templateId,
    required this.templateName,
    required this.dayOfWeek,
    required this.cycleLength,
    required this.cycleIndex,
  });

  /// Short label for lists (e.g. "Every week", "Week 3 of 4").
  String get repeatLabel {
    if (cycleLength <= 1) return 'Every week';
    return 'Week ${cycleIndex + 1} of $cycleLength';
  }

  String get dayName {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[dayOfWeek - 1];
  }

  String get dayFullName {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[dayOfWeek - 1];
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'template_id': templateId,
        'template_name': templateName,
        'day_of_week': dayOfWeek,
        'cycle_length': cycleLength,
        'cycle_index': cycleIndex,
        // Keep legacy column in sync for older DB schemas that still have it.
        'week_pattern': _legacyWeekPatternValue(),
      };

  String _legacyWeekPatternValue() {
    if (cycleLength <= 1) return 'every';
    if (cycleLength == 2 && cycleIndex == 0) return 'week_a';
    if (cycleLength == 2 && cycleIndex == 1) return 'week_b';
    return 'every';
  }

  factory ScheduleEntry.fromMap(Map<String, dynamic> map) {
    var cycleLength = (map['cycle_length'] as int?) ?? 1;
    var cycleIndex = (map['cycle_index'] as int?) ?? 0;

    final hasCycleCols =
        map.containsKey('cycle_length') && map['cycle_length'] != null;

    if (!hasCycleCols) {
      final legacy = _LegacyWeekPattern.fromDb(map['week_pattern'] as String?);
      switch (legacy) {
        case _LegacyWeekPattern.weekA:
          cycleLength = 2;
          cycleIndex = 0;
        case _LegacyWeekPattern.weekB:
          cycleLength = 2;
          cycleIndex = 1;
        case _LegacyWeekPattern.every:
        case null:
          cycleLength = 1;
          cycleIndex = 0;
      }
    }

    cycleLength = cycleLength.clamp(1, 8);
    if (cycleLength <= 1) {
      cycleIndex = 0;
    } else {
      cycleIndex = cycleIndex.clamp(0, cycleLength - 1);
    }

    return ScheduleEntry(
      id: map['id'] as String,
      templateId: map['template_id'] as String,
      templateName: map['template_name'] as String,
      dayOfWeek: map['day_of_week'] as int,
      cycleLength: cycleLength,
      cycleIndex: cycleIndex,
    );
  }
}

class UpcomingWorkout {
  final DateTime date;
  final ScheduleEntry entry;

  const UpcomingWorkout({required this.date, required this.entry});

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
