import 'package:health/health.dart';
import '../models/health_entry.dart';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  static final _health = Health();
  static bool _configured = false;

  static const _bodyTypes = [
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
  ];

  static const _dashboardTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.WORKOUT,
  ];

  Future<void> _configure() async {
    if (!_configured) {
      await _health.configure();
      _configured = true;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      await _configure();
      return await _health.requestAuthorization(
        [..._bodyTypes, ..._dashboardTypes],
      );
    } catch (_) {
      return false;
    }
  }

  Future<BodyMetrics> fetchBodyMetrics({int daysBack = 90}) async {
    try {
      await _configure();
      final now = DateTime.now();
      final start = now.subtract(Duration(days: daysBack));

      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: _bodyTypes,
      );

      HealthEntry toEntry(HealthDataPoint p, String unit) => HealthEntry(
            date: DateTime(p.dateFrom.year, p.dateFrom.month, p.dateFrom.day),
            value: (p.value as NumericHealthValue).numericValue.toDouble(),
            unit: unit,
          );

      final weightHistory = data
          .where((p) =>
              p.type == HealthDataType.WEIGHT && p.value is NumericHealthValue)
          .map((p) => toEntry(p, 'kg'))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final fatHistory = data
          .where((p) =>
              p.type == HealthDataType.BODY_FAT_PERCENTAGE &&
              p.value is NumericHealthValue)
          .map((p) => toEntry(p, '%'))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      return BodyMetrics(
        latestWeight: weightHistory.isNotEmpty ? weightHistory.last : null,
        latestBodyFat: fatHistory.isNotEmpty ? fatHistory.last : null,
        weightHistory: weightHistory,
        bodyFatHistory: fatHistory,
      );
    } catch (_) {
      return BodyMetrics.empty;
    }
  }

  Future<HealthDashboardData> fetchHealthData({int daysBack = 90}) async {
    try {
      await _configure();
      final now = DateTime.now();
      final start = now.subtract(Duration(days: daysBack));

      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: _dashboardTypes,
      );

      // Heart rate
      final heartRate = data
          .where((p) =>
              p.type == HealthDataType.HEART_RATE &&
              p.value is NumericHealthValue)
          .map((p) => HeartRateEntry(
                date: p.dateFrom,
                bpm: (p.value as NumericHealthValue).numericValue.toDouble(),
              ))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      // Blood pressure — pair systolic/diastolic by timestamp proximity
      final systolicPts = data
          .where((p) =>
              p.type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC &&
              p.value is NumericHealthValue)
          .toList();
      final diastolicPts = data
          .where((p) =>
              p.type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC &&
              p.value is NumericHealthValue)
          .toList();

      final bpHistory = <BloodPressureEntry>[];
      for (final sys in systolicPts) {
        HealthDataPoint? dia;
        for (final d in diastolicPts) {
          if (d.dateFrom.difference(sys.dateFrom).inSeconds.abs() < 60) {
            dia = d;
            break;
          }
        }
        if (dia != null) {
          bpHistory.add(BloodPressureEntry(
            date: sys.dateFrom,
            systolic:
                (sys.value as NumericHealthValue).numericValue.toDouble(),
            diastolic:
                (dia.value as NumericHealthValue).numericValue.toDouble(),
          ));
        }
      }
      bpHistory.sort((a, b) => a.date.compareTo(b.date));

      // Sleep segments
      final sleepHistory = data
          .where((p) => p.type == HealthDataType.SLEEP_ASLEEP)
          .map((p) => SleepEntry(start: p.dateFrom, end: p.dateTo))
          .where((e) => e.duration.inMinutes > 0)
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));

      // Workouts
      final workouts = data
          .where((p) =>
              p.type == HealthDataType.WORKOUT &&
              p.value is WorkoutHealthValue)
          .map((p) {
            final w = p.value as WorkoutHealthValue;
            return HealthWorkoutEntry(
              start: p.dateFrom,
              end: p.dateTo,
              activityType: _formatActivityType(w.workoutActivityType.name),
              energyKcal: w.totalEnergyBurned?.toDouble(),
              distanceMeters: w.totalDistance?.toDouble(),
            );
          })
          .where((w) => w.duration.inMinutes > 0)
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));

      return HealthDashboardData(
        heartRateHistory: heartRate,
        bloodPressureHistory: bpHistory,
        sleepHistory: sleepHistory,
        workoutHistory: workouts,
      );
    } catch (_) {
      return HealthDashboardData.empty;
    }
  }

  static String _formatActivityType(String enumName) {
    return enumName
        .split('_')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
