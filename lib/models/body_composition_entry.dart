import 'health_entry.dart';

class BodyCompositionEntry {
  final String id;
  final DateTime measuredAt;
  final double weightKg;
  final double? bodyFatPct;
  final double? bodyFatKg;
  final double? skeletalMuscleMassPct;
  final double? skeletalMuscleMassKg;
  final double? fatFreeMassKg;
  final double? bodyWaterPct;
  final double? visceralFat;
  final double? boneMineralKg;
  final double? proteinPct;

  const BodyCompositionEntry({
    required this.id,
    required this.measuredAt,
    required this.weightKg,
    this.bodyFatPct,
    this.bodyFatKg,
    this.skeletalMuscleMassPct,
    this.skeletalMuscleMassKg,
    this.fatFreeMassKg,
    this.bodyWaterPct,
    this.visceralFat,
    this.boneMineralKg,
    this.proteinPct,
  });

  DateTime get dateOnly => DateTime(measuredAt.year, measuredAt.month, measuredAt.day);

  Map<String, Object?> toMap() => {
        'id': id,
        'measured_at': dateOnly.millisecondsSinceEpoch,
        'weight_kg': weightKg,
        'body_fat_pct': bodyFatPct,
        'body_fat_kg': bodyFatKg,
        'skeletal_muscle_mass_pct': skeletalMuscleMassPct,
        'skeletal_muscle_mass_kg': skeletalMuscleMassKg,
        'fat_free_mass_kg': fatFreeMassKg,
        'body_water_pct': bodyWaterPct,
        'visceral_fat': visceralFat,
        'bone_mineral_kg': boneMineralKg,
        'protein_pct': proteinPct,
      };

  factory BodyCompositionEntry.fromMap(Map<String, Object?> map) {
    double? d(Object? v) =>
        v == null ? null : (v as num).toDouble();

    return BodyCompositionEntry(
      id: map['id']! as String,
      measuredAt: DateTime.fromMillisecondsSinceEpoch(
        (map['measured_at']! as num).toInt(),
      ),
      weightKg: (map['weight_kg']! as num).toDouble(),
      bodyFatPct: d(map['body_fat_pct']),
      bodyFatKg: d(map['body_fat_kg']),
      skeletalMuscleMassPct: d(map['skeletal_muscle_mass_pct']),
      skeletalMuscleMassKg: d(map['skeletal_muscle_mass_kg']),
      fatFreeMassKg: d(map['fat_free_mass_kg']),
      bodyWaterPct: d(map['body_water_pct']),
      visceralFat: d(map['visceral_fat']),
      boneMineralKg: d(map['bone_mineral_kg']),
      proteinPct: d(map['protein_pct']),
    );
  }
}

int _dayKey(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

BodyMetrics bodyMetricsFromEntries(List<BodyCompositionEntry> entries) {
  if (entries.isEmpty) {
    return BodyMetrics.empty;
  }
  final sorted = [...entries]..sort((a, b) => a.dateOnly.compareTo(b.dateOnly));
  final last = sorted.last;
  BodyCompositionEntry? lastWithFat;
  for (final e in sorted.reversed) {
    if (e.bodyFatPct != null) {
      lastWithFat = e;
      break;
    }
  }

  final weightHistory = sorted
      .map(
        (e) => HealthEntry(date: e.dateOnly, value: e.weightKg, unit: 'kg'),
      )
      .toList();

  final bodyFatHistory = sorted
      .where((e) => e.bodyFatPct != null)
      .map(
        (e) => HealthEntry(date: e.dateOnly, value: e.bodyFatPct!, unit: '%'),
      )
      .toList();

  return BodyMetrics(
    latestWeight: HealthEntry(date: last.dateOnly, value: last.weightKg, unit: 'kg'),
    latestBodyFat: lastWithFat != null
        ? HealthEntry(
            date: lastWithFat.dateOnly,
            value: lastWithFat.bodyFatPct!,
            unit: '%',
          )
        : null,
    weightHistory: weightHistory,
    bodyFatHistory: bodyFatHistory,
  );
}

enum BodyChartMetric {
  weight,
  bodyFatPct,
  bodyFatKg,
  skeletalMuscleMassPct,
  skeletalMuscleMassKg,
  fatFreeMassKg,
  bodyWaterPct,
  visceralFat,
  boneMineralKg,
  proteinPct,
}

extension BodyChartMetricLabels on BodyChartMetric {
  String get label => switch (this) {
        BodyChartMetric.weight => 'Weight',
        BodyChartMetric.bodyFatPct => 'Body fat %',
        BodyChartMetric.bodyFatKg => 'Body fat kg',
        BodyChartMetric.skeletalMuscleMassPct => 'Muscle %',
        BodyChartMetric.skeletalMuscleMassKg => 'Muscle kg',
        BodyChartMetric.fatFreeMassKg => 'Fat-free mass',
        BodyChartMetric.bodyWaterPct => 'Body water %',
        BodyChartMetric.visceralFat => 'Visceral fat',
        BodyChartMetric.boneMineralKg => 'Bone mineral kg',
        BodyChartMetric.proteinPct => 'Protein %',
      };

  String get unit => switch (this) {
        BodyChartMetric.weight => 'kg',
        BodyChartMetric.bodyFatPct => '%',
        BodyChartMetric.bodyFatKg => 'kg',
        BodyChartMetric.skeletalMuscleMassPct => '%',
        BodyChartMetric.skeletalMuscleMassKg => 'kg',
        BodyChartMetric.fatFreeMassKg => 'kg',
        BodyChartMetric.bodyWaterPct => '%',
        BodyChartMetric.visceralFat => '',
        BodyChartMetric.boneMineralKg => 'kg',
        BodyChartMetric.proteinPct => '%',
      };

  double? value(BodyCompositionEntry e) => switch (this) {
        BodyChartMetric.weight => e.weightKg,
        BodyChartMetric.bodyFatPct => e.bodyFatPct,
        BodyChartMetric.bodyFatKg => e.bodyFatKg,
        BodyChartMetric.skeletalMuscleMassPct => e.skeletalMuscleMassPct,
        BodyChartMetric.skeletalMuscleMassKg => e.skeletalMuscleMassKg,
        BodyChartMetric.fatFreeMassKg => e.fatFreeMassKg,
        BodyChartMetric.bodyWaterPct => e.bodyWaterPct,
        BodyChartMetric.visceralFat => e.visceralFat,
        BodyChartMetric.boneMineralKg => e.boneMineralKg,
        BodyChartMetric.proteinPct => e.proteinPct,
      };
}

List<HealthEntry> bodyCompositionSeries(
  List<BodyCompositionEntry> entries,
  BodyChartMetric metric,
) {
  final sorted = [...entries]..sort((a, b) => a.dateOnly.compareTo(b.dateOnly));
  final out = <HealthEntry>[];
  for (final e in sorted) {
    final v = metric.value(e);
    if (v != null) {
      out.add(HealthEntry(date: e.dateOnly, value: v, unit: metric.unit));
    }
  }
  return out;
}

Iterable<BodyChartMetric> metricsWithSeries(List<BodyCompositionEntry> entries) sync* {
  for (final m in BodyChartMetric.values) {
    if (bodyCompositionSeries(entries, m).length >= 2) {
      yield m;
    }
  }
}

extension BodyMetricsMerge on BodyMetrics {
  BodyMetrics mergedWith(BodyMetrics health) {
    if (health.weightHistory.isEmpty && health.bodyFatHistory.isEmpty) {
      return this;
    }

    HealthEntry? pickLatest(List<HealthEntry> list) {
      if (list.isEmpty) return null;
      return list.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
    }

    final weightByDay = <int, HealthEntry>{};
    for (final e in health.weightHistory) {
      weightByDay[_dayKey(e.date)] = e;
    }
    for (final e in weightHistory) {
      weightByDay[_dayKey(e.date)] = e;
    }
    final mergedWeight = weightByDay.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final fatByDay = <int, HealthEntry>{};
    for (final e in health.bodyFatHistory) {
      fatByDay[_dayKey(e.date)] = e;
    }
    for (final e in bodyFatHistory) {
      fatByDay[_dayKey(e.date)] = e;
    }
    final mergedFat = fatByDay.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return BodyMetrics(
      latestWeight: pickLatest(mergedWeight),
      latestBodyFat: pickLatest(mergedFat),
      weightHistory: mergedWeight,
      bodyFatHistory: mergedFat,
    );
  }
}
