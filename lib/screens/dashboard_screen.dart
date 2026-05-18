import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../models/body_composition_entry.dart';
import '../models/health_entry.dart';
import '../models/schedule.dart';
import '../services/body_composition_service.dart';
import '../services/health_service.dart';
import '../services/schedule_service.dart';
import '../services/workout_service.dart';
import '../theme/app_theme.dart';
import '../utils/body_composition_import.dart';
import '../widgets/metric_card.dart';
import '../widgets/body_composition_overview_chart.dart';
import 'active_workout_screen.dart';
import 'add_body_composition_screen.dart';
import 'health_metric_detail_screen.dart';

enum _LoadState { idle, loading, loaded, error }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _healthService = HealthService();
  final _composition = BodyCompositionService.instance;
  final _scheduleService = ScheduleService.instance;
  final _workoutService = WorkoutService.instance;

  BodyMetrics _metrics = BodyMetrics.empty;
  List<BodyCompositionEntry> _entries = [];
  HealthDashboardData _healthData = HealthDashboardData.empty;
  List<UpcomingWorkout> _upcoming = [];
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
      final results = await Future.wait([
        _composition.listEntries(),
        _scheduleService.getUpcomingWorkouts(days: 7),
      ]);
      final local = results[0] as List<BodyCompositionEntry>;
      final upcoming = results[1] as List<UpcomingWorkout>;

      var metrics = bodyMetricsFromEntries(local);

      final granted = await _healthService.requestPermissions();
      if (granted) {
        final health = await _healthService.fetchBodyMetrics();
        metrics = metrics.mergedWith(health);
      }

      HealthDashboardData healthData = HealthDashboardData.empty;
      if (granted) {
        healthData = await _healthService.fetchHealthData();
      }

      setState(() {
        _entries = local;
        _metrics = metrics;
        _healthData = healthData;
        _upcoming = upcoming;
        _state = _LoadState.loaded;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _state = _LoadState.error;
      });
    }
  }

  Future<void> _openAdd() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddBodyCompositionScreen()),
    );
    if (changed == true) await _load();
  }

  Future<void> _showImportSheet() async {
    final controller = TextEditingController();
    final imported = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Paste spreadsheet rows',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Tab-separated (or header + data). Date as D.M.YYYY.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 10,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.card,
                  hintText: 'Date\tWeight\tBody fat % …',
                  hintStyle:
                      const TextStyle(color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  try {
                    final list =
                        parseBodyCompositionPaste(controller.text);
                    final n = await _composition.importEntries(list);
                    if (ctx.mounted) Navigator.of(ctx).pop(n);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Import'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (imported != null && imported > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $imported rows')),
      );
      await _load();
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
              Text(
                'Dashboard',
                style: Theme.of(context).textTheme.displayMedium,
              ),
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
          else ...[
            IconButton(
              onPressed: _showImportSheet,
              icon: const Icon(Icons.upload_file_outlined),
              color: AppColors.textSecondary,
              tooltip: 'Import',
            ),
            IconButton(
              onPressed: _openAdd,
              icon: const Icon(Icons.add_circle_outline),
              color: AppColors.accent,
              tooltip: 'Add measurement',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    return switch (_state) {
      _LoadState.idle || _LoadState.loading => _buildLoading(),
      _LoadState.error => _buildError(),
      _LoadState.loaded => _buildLoaded(),
    };
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: MetricCard(
              label: 'Weight',
              value: null,
              unit: 'kg',
              accentColor: AppColors.weightColor,
              icon: Icons.monitor_weight_outlined,
              isLoading: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MetricCard(
              label: 'Body Fat',
              value: null,
              unit: '%',
              accentColor: AppColors.fatColor,
              icon: Icons.percent_rounded,
              isLoading: true,
            ),
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
          Text(
            _errorMessage,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _startWorkout(UpcomingWorkout w) async {
    final template = await _workoutService.getWorkoutTemplate(w.entry.templateId);
    if (!mounted) return;
    if (template == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout template no longer exists')),
      );
      return;
    }
    if (template.exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add exercises to this workout first')),
      );
      return;
    }

    final activeSession = await _workoutService.getActiveSession();
    if (!mounted) return;
    if (activeSession != null) {
      final abandon = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Active Workout',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            'You have an active "${activeSession.templateName}" workout. Abandon it?',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: const Text('Abandon & Start'),
            ),
          ],
        ),
      );
      if (abandon != true) return;
      await _workoutService.abandonSession(activeSession.id);
    }

    if (!mounted) return;
    final session = await _workoutService.startWorkoutSession(template);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ActiveWorkoutScreen(session: session)),
    );
  }

  Widget _buildLoaded() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_upcoming.isNotEmpty) _buildUpcomingSection(),
        _buildBodyCompositionSection(),
        if (!_healthData.isEmpty) _buildHealthSection(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildUpcomingSection() {
    final shown = _upcoming.take(1).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UPCOMING TRAINING',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (int i = 0; i < shown.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.divider, indent: 16),
                  _buildUpcomingRow(shown[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingRow(UpcomingWorkout w) {
    final isToday = w.isToday;
    return InkWell(
      onTap: () => _startWorkout(w),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEE').format(w.date).toUpperCase(),
                    style: TextStyle(
                      color: isToday ? AppColors.accent : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    DateFormat('d').format(w.date),
                    style: TextStyle(
                      color: isToday ? AppColors.accent : AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.entry.templateName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (w.isMoved) ...[
                    const SizedBox(height: 2),
                    const Text(
                      'Moved',
                      style: TextStyle(color: AppColors.warning, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (isToday)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.divider,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyCompositionSection() {
    final weight = _metrics.latestWeight;
    final fat = _metrics.latestBodyFat;
    final hasAny = weight != null || fat != null;

    if (!hasAny && _entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
        child: Column(
          children: [
            Text(
              'No measurements yet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Paste your scale export or add a row manually.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _showImportSheet,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Import paste'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add measurement'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.divider),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );
    }

    String? weightChange;
    String? fatChange;
    if (_metrics.weightHistory.length >= 2) {
      weightChange = _get7DayChange(_metrics.weightHistory,
          (v) => '${v.toStringAsFixed(1)} kg');
    }
    if (_metrics.bodyFatHistory.length >= 2) {
      fatChange = _get7DayChange(_metrics.bodyFatHistory,
          (v) => '${v.toStringAsFixed(1)}%');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Weight',
                  value: weight?.value.toStringAsFixed(1),
                  unit: 'kg',
                  subtitle: weightChange,
                  accentColor: AppColors.weightColor,
                  icon: Icons.monitor_weight_outlined,
                  onTap: _metrics.weightHistory.isNotEmpty
                      ? () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => HealthMetricDetailScreen(
                              title: 'Weight History',
                              entries: _metrics.weightHistory,
                              accentColor: AppColors.weightColor,
                              unit: 'kg',
                              formatter: (v) => '${v.toStringAsFixed(1)} kg',
                            ),
                          ))
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: 'Body Fat',
                  value: fat?.value.toStringAsFixed(1),
                  unit: '%',
                  subtitle: fatChange,
                  accentColor: AppColors.fatColor,
                  icon: Icons.percent_rounded,
                  onTap: _metrics.bodyFatHistory.isNotEmpty
                      ? () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => HealthMetricDetailScreen(
                              title: 'Body Fat History',
                              entries: _metrics.bodyFatHistory,
                              accentColor: AppColors.fatColor,
                              unit: '%',
                              formatter: (v) => '${v.toStringAsFixed(1)}%',
                            ),
                          ))
                      : null,
                ),
              ),
            ],
          ),
        ),
        if (_entries.length >= 2) ...[
          const SizedBox(height: 16),
          BodyCompositionOverviewChart(entries: _entries),
        ],
      ],
    );
  }

  Widget _buildHealthSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_healthData.heartRateHistory.isNotEmpty) _buildHeartRateCard(),
        if (_healthData.sleepHistory.isNotEmpty) _buildSleepCard(),
        if (_healthData.bloodPressureHistory.isNotEmpty)
          _buildBloodPressureCard(),
      ],
    );
  }

  Widget _buildHeartRateCard() {
    final sorted = _healthData.heartRateHistory;
    final latest = sorted.last;
    final now = DateTime.now();
    final recent7d =
        sorted.where((e) => now.difference(e.date).inDays <= 7).toList();
    final avg7d = recent7d.isEmpty
        ? null
        : recent7d.map((e) => e.bpm).reduce((a, b) => a + b) /
            recent7d.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: MetricCard(
              label: 'Heart Rate',
              value: latest.bpm.toStringAsFixed(0),
              unit: 'bpm',
              subtitle: avg7d != null
                  ? 'avg ${avg7d.toStringAsFixed(0)} bpm (7d)'
                  : DateFormat.yMMMd().format(latest.date),
              accentColor: AppColors.heartRateColor,
              icon: Icons.favorite_outlined,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => HealthMetricDetailScreen(
                  title: 'Heart Rate',
                  entries: sorted
                      .map((e) =>
                          HealthEntry(date: e.date, value: e.bpm, unit: 'bpm'))
                      .toList(),
                  accentColor: AppColors.heartRateColor,
                  unit: 'bpm',
                  formatter: (v) => '${v.toStringAsFixed(0)} bpm',
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepCard() {
    final byNight = _groupSleepByNight(_healthData.sleepHistory);
    if (byNight.isEmpty) return const SizedBox.shrink();

    final sortedNights = byNight.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final lastNight = sortedNights.first;
    final recent7 = sortedNights.take(7).toList();
    final avgMinutes =
        recent7.map((e) => e.value.inMinutes).reduce((a, b) => a + b) /
            recent7.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: MetricCard(
              label: 'Sleep Last Night',
              value: _hoursDecimal(lastNight.value),
              unit: 'hrs',
              subtitle: '7d avg ${_hoursDecimal(Duration(minutes: avgMinutes.round()))} hrs',
              accentColor: AppColors.sleepColor,
              icon: Icons.bedtime_outlined,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SleepDetailScreen(nightsByDate: byNight),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodPressureCard() {
    final latest = _healthData.bloodPressureHistory.last;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: MetricCard(
              label: 'Blood Pressure',
              value:
                  '${latest.systolic.toStringAsFixed(0)}/${latest.diastolic.toStringAsFixed(0)}',
              unit: 'mmHg',
              subtitle: DateFormat.yMMMd().format(latest.date),
              accentColor: AppColors.accent,
              icon: Icons.water_drop_outlined,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BloodPressureDetailScreen(
                  readings: _healthData.bloodPressureHistory,
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  String? _get7DayChange(
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

  String _hoursDecimal(Duration d) =>
      (d.inMinutes / 60.0).toStringAsFixed(1);
}
