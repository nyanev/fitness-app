import '../models/health_entry.dart';

/// Returns a human-readable description of how a metric changed over the last
/// 7 days (e.g. `+1.2 kg in 7 days`), or null if there is too little data.
String? sevenDayChange(
    List<HealthEntry> entries, String Function(double) fmt) {
  if (entries.length < 2) return null;
  final recent = entries.reversed.toList();
  final latest = recent.first.value;
  final older = recent.firstWhere(
    (e) => recent.first.date.difference(e.date).inDays >= 7,
    orElse: () => recent.last,
  );
  final diff = latest - older.value;
  if (diff.abs() < 0.01) return 'No change in 7 days';
  final sign = diff > 0 ? '+' : '';
  return '$sign${fmt(diff)} in 7 days';
}

/// Groups SLEEP_ASLEEP segments into nightly totals.
/// Segments ending before noon are attributed to the previous calendar day.
Map<DateTime, Duration> groupSleepByNight(List<SleepEntry> entries) {
  final byNight = <DateTime, Duration>{};
  for (final e in entries) {
    final end = e.end;
    final night = end.hour < 12
        ? DateTime(end.year, end.month, end.day)
            .subtract(const Duration(days: 1))
        : DateTime(end.year, end.month, end.day);
    byNight[night] = (byNight[night] ?? Duration.zero) + e.duration;
  }
  return byNight;
}
