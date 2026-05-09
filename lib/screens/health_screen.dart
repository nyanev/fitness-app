import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../models/health_entry.dart';
import '../services/health_service.dart';
import '../theme/app_theme.dart';
import '../widgets/metric_card.dart';
import '../widgets/trend_chart.dart';

enum _LoadState { idle, loading, loaded, denied, error }

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final _service = HealthService();
  HealthDashboardData _data = HealthDashboardData.empty;
  _LoadState _state = _LoadState.idle;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final granted = await _service.requestPermissions();
      if (!granted) {
        setState(() => _state = _LoadState.denied);
        return;
      }
      final data = await _service.fetchHealthData();
      setState(() {
        _data = data;
        _state = _LoadState.loaded;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _state = _LoadState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.accent,
          backgroundColor: AppColors.card,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Health', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 2),
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const Spacer(),
          if (_state == _LoadState.loading)
            const CupertinoActivityIndicator(color: AppColors.textSecondary)
          else
            GestureDetector(
              onTap: _load,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return switch (_state) {
      _LoadState.idle || _LoadState.loading => _buildLoading(),
      _LoadState.denied => _buildDenied(),
      _LoadState.error => _buildError(),
      _LoadState.loaded => _buildLoaded(),
    };
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Heart Rate',
                  value: null,
                  unit: 'bpm',
                  accentColor: AppColors.heartRateColor,
                  icon: Icons.favorite_outlined,
                  isLoading: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: 'Blood Pressure',
                  value: null,
                  unit: 'mmHg',
                  accentColor: AppColors.accent,
                  icon: Icons.water_drop_outlined,
                  isLoading: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDenied() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          const Icon(
            Icons.health_and_safety_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 20),
          Text(
            'Health Access Required',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Grant access in Settings → Privacy & Security → Health → Fitness App to view your workouts, sleep, heart rate, and blood pressure.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 20),
          Text('Something went wrong',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(_errorMessage,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoaded() {
    if (_data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            const Icon(
              Icons.health_and_safety_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 20),
            Text(
              'No Health Data',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Start tracking workouts, sleep, and vitals in the Health app.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_data.heartRateHistory.isNotEmpty) _buildHeartRateSection(),
        if (_data.bloodPressureHistory.isNotEmpty)
          _buildBloodPressureSection(),
        if (_data.sleepHistory.isNotEmpty) _buildSleepSection(),
        if (_data.workoutHistory.isNotEmpty) _buildWorkoutsSection(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHeartRateSection() {
    final sorted = _data.heartRateHistory;
    final latest = sorted.last;
    final now = DateTime.now();
    final recent7d =
        sorted.where((e) => now.difference(e.date).inDays <= 7).toList();

    double? avg7d;
    double? min7d;
    double? max7d;
    if (recent7d.isNotEmpty) {
      avg7d = recent7d.map((e) => e.bpm).reduce((a, b) => a + b) /
          recent7d.length;
      min7d = recent7d.map((e) => e.bpm).reduce((a, b) => a < b ? a : b);
      max7d = recent7d.map((e) => e.bpm).reduce((a, b) => a > b ? a : b);
    }

    final chartEntries = sorted
        .map((e) => HealthEntry(date: e.date, value: e.bpm, unit: 'bpm'))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child:
              Text('Heart Rate', style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Latest',
                  value: latest.bpm.toStringAsFixed(0),
                  unit: 'bpm',
                  subtitle: avg7d != null
                      ? 'avg ${avg7d.toStringAsFixed(0)} bpm (7d)'
                      : DateFormat.yMMMd().format(latest.date),
                  accentColor: AppColors.heartRateColor,
                  icon: Icons.favorite_outlined,
                ),
              ),
              if (min7d != null && max7d != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Range 7d',
                    value: '${min7d.toStringAsFixed(0)}–${max7d.toStringAsFixed(0)}',
                    unit: 'bpm',
                    subtitle: '${recent7d.length} readings',
                    accentColor: AppColors.heartRateColor,
                    icon: Icons.show_chart,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (chartEntries.length >= 2) ...[
          const SizedBox(height: 12),
          TrendChart(
            entries: chartEntries,
            color: AppColors.heartRateColor,
            unit: 'bpm',
          ),
        ],
      ],
    );
  }

  Widget _buildBloodPressureSection() {
    final readings = _data.bloodPressureHistory.reversed.take(10).toList();
    final latest = readings.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Blood Pressure',
              style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: MetricCard(
            label: 'Latest',
            value:
                '${latest.systolic.toStringAsFixed(0)}/${latest.diastolic.toStringAsFixed(0)}',
            unit: 'mmHg',
            subtitle: DateFormat.yMMMd().format(latest.date),
            accentColor: AppColors.accent,
            icon: Icons.water_drop_outlined,
          ),
        ),
        if (readings.length > 1) ...[
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: readings.length,
              separatorBuilder: (_, __) => const Divider(
                  color: AppColors.divider, height: 1, indent: 16),
              itemBuilder: (_, i) {
                final r = readings[i];
                final category = _bpCategory(r.systolic, r.diastolic);
                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.water_drop_outlined,
                        color: AppColors.accent, size: 18),
                  ),
                  title: Text(
                    '${r.systolic.toStringAsFixed(0)} / ${r.diastolic.toStringAsFixed(0)} mmHg',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${DateFormat.yMMMd().format(r.date)}  ·  $category',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSleepSection() {
    final byNight = _groupSleepByNight(_data.sleepHistory);
    if (byNight.isEmpty) return const SizedBox.shrink();

    final sortedNights = byNight.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final lastNight = sortedNights.first;
    final recent7 = sortedNights.take(7).toList();
    final avgMinutes = recent7.map((e) => e.value.inMinutes).reduce((a, b) => a + b) /
        recent7.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Sleep', style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Last Night',
                  value: _hoursDecimal(lastNight.value),
                  unit: 'hrs',
                  subtitle: '${_formatDuration(lastNight.value)}  ·  ${DateFormat.MMMd().format(lastNight.key)}',
                  accentColor: AppColors.sleepColor,
                  icon: Icons.bedtime_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: '7-Day Avg',
                  value: _hoursDecimal(Duration(minutes: avgMinutes.round())),
                  unit: 'hrs',
                  subtitle: '${recent7.length} nights tracked',
                  accentColor: AppColors.sleepColor,
                  icon: Icons.nights_stay_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedNights.take(14).length,
            separatorBuilder: (_, __) =>
                const Divider(color: AppColors.divider, height: 1, indent: 16),
            itemBuilder: (_, i) {
              final night = sortedNights[i];
              return ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.sleepColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bedtime_outlined,
                      color: AppColors.sleepColor, size: 18),
                ),
                title: Text(
                  _formatDuration(night.value),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  DateFormat('EEE, MMM d').format(night.key),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutsSection() {
    final recent = _data.workoutHistory.reversed.take(30).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child:
              Text('Workouts', style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            separatorBuilder: (_, __) =>
                const Divider(color: AppColors.divider, height: 1, indent: 16),
            itemBuilder: (_, i) {
              final w = recent[i];
              final parts = [
                _formatDuration(w.duration),
                if (w.energyKcal != null)
                  '${w.energyKcal!.toStringAsFixed(0)} kcal',
                if (w.distanceMeters != null)
                  _formatDistance(w.distanceMeters!),
              ];
              return ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.workoutColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_workoutIcon(w.activityType),
                      color: AppColors.workoutColor, size: 18),
                ),
                title: Text(
                  w.activityType,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${DateFormat('EEE, MMM d').format(w.start)}  ·  ${parts.join(' · ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Groups SLEEP_ASLEEP segments into nightly totals.
  // Segments ending before noon are attributed to the previous calendar day.
  Map<DateTime, Duration> _groupSleepByNight(List<SleepEntry> entries) {
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

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _hoursDecimal(Duration d) =>
      (d.inMinutes / 60.0).toStringAsFixed(1);

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  String _bpCategory(double sys, double dia) {
    if (sys < 120 && dia < 80) return 'Normal';
    if (sys < 130 && dia < 80) return 'Elevated';
    if (sys < 140 || dia < 90) return 'High Stage 1';
    return 'High Stage 2';
  }

  IconData _workoutIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('run')) return Icons.directions_run;
    if (lower.contains('cycl') || lower.contains('bik')) {
      return Icons.directions_bike;
    }
    if (lower.contains('swim')) return Icons.pool;
    if (lower.contains('walk')) return Icons.directions_walk;
    if (lower.contains('yoga')) return Icons.self_improvement;
    if (lower.contains('strength') || lower.contains('functional')) {
      return Icons.fitness_center;
    }
    if (lower.contains('hik')) return Icons.terrain;
    if (lower.contains('soccer') || lower.contains('football')) {
      return Icons.sports_soccer;
    }
    if (lower.contains('basketball')) return Icons.sports_basketball;
    if (lower.contains('tennis')) return Icons.sports_tennis;
    if (lower.contains('elliptical')) return Icons.directions_walk;
    if (lower.contains('rowing')) return Icons.rowing;
    if (lower.contains('stair')) return Icons.stairs;
    return Icons.sports;
  }
}
