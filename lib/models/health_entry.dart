class HealthEntry {
  final DateTime date;
  final double value;
  final String unit;

  const HealthEntry({
    required this.date,
    required this.value,
    required this.unit,
  });
}

class BodyMetrics {
  final HealthEntry? latestWeight;
  final HealthEntry? latestBodyFat;
  final List<HealthEntry> weightHistory;
  final List<HealthEntry> bodyFatHistory;

  const BodyMetrics({
    this.latestWeight,
    this.latestBodyFat,
    required this.weightHistory,
    required this.bodyFatHistory,
  });

  static const BodyMetrics empty = BodyMetrics(
    weightHistory: [],
    bodyFatHistory: [],
  );
}

class HeartRateEntry {
  final DateTime date;
  final double bpm;
  const HeartRateEntry({required this.date, required this.bpm});
}

class BloodPressureEntry {
  final DateTime date;
  final double systolic;
  final double diastolic;
  const BloodPressureEntry({
    required this.date,
    required this.systolic,
    required this.diastolic,
  });
}

class SleepEntry {
  final DateTime start;
  final DateTime end;
  Duration get duration => end.difference(start);
  const SleepEntry({required this.start, required this.end});
}

class HealthWorkoutEntry {
  final DateTime start;
  final DateTime end;
  final String activityType;
  final double? energyKcal;
  final double? distanceMeters;
  Duration get duration => end.difference(start);
  const HealthWorkoutEntry({
    required this.start,
    required this.end,
    required this.activityType,
    this.energyKcal,
    this.distanceMeters,
  });
}

class HealthDashboardData {
  final List<HeartRateEntry> heartRateHistory;
  final List<BloodPressureEntry> bloodPressureHistory;
  final List<SleepEntry> sleepHistory;
  final List<HealthWorkoutEntry> workoutHistory;

  const HealthDashboardData({
    this.heartRateHistory = const [],
    this.bloodPressureHistory = const [],
    this.sleepHistory = const [],
    this.workoutHistory = const [],
  });

  static const empty = HealthDashboardData();

  bool get isEmpty =>
      heartRateHistory.isEmpty &&
      bloodPressureHistory.isEmpty &&
      sleepHistory.isEmpty &&
      workoutHistory.isEmpty;
}
