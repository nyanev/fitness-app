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
