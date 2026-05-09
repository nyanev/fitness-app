import '../models/health_entry.dart';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  Future<bool> requestPermissions() async => true;

  Future<BodyMetrics> fetchBodyMetrics({int daysBack = 90}) async {
    return BodyMetrics.empty;
  }
}
