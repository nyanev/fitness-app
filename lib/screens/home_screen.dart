import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../models/body_composition_entry.dart';
import '../models/health_entry.dart';
import '../services/body_composition_service.dart';
import '../services/health_service.dart';
import '../theme/app_theme.dart';
import '../utils/body_composition_import.dart';
import '../widgets/metric_card.dart';
import '../widgets/history_tile.dart';
import '../widgets/body_composition_overview_chart.dart';
import '../widgets/trend_chart.dart';
import 'add_body_composition_screen.dart';

enum LoadState { idle, loading, loaded, denied, error }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = HealthService();
  final _composition = BodyCompositionService.instance;
  BodyMetrics _metrics = BodyMetrics.empty;
  List<BodyCompositionEntry> _entries = [];
  LoadState _state = LoadState.idle;
  String _errorMessage = '';
  BodyChartMetric? _selectedChartMetric;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = LoadState.loading);

    try {
      final local = await _composition.listEntries();
      var metrics = bodyMetricsFromEntries(local);

      final granted = await _service.requestPermissions();
      if (granted) {
        final health = await _service.fetchBodyMetrics();
        metrics = metrics.mergedWith(health);
      } else if (local.isEmpty) {
        setState(() => _state = LoadState.denied);
        return;
      }

      final available = metricsWithSeries(local).toList();
      BodyChartMetric? chart = _selectedChartMetric;
      if (chart == null || !available.contains(chart)) {
        chart = available.isNotEmpty ? available.first : null;
      }

      setState(() {
        _entries = local;
        _metrics = metrics;
        _selectedChartMetric = chart;
        _state = LoadState.loaded;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _state = LoadState.error;
      });
    }
  }

  String _formatWeight(double kg) => '${kg.toStringAsFixed(1)} kg';
  String _formatFat(double pct) => '${pct.toStringAsFixed(1)}%';

  String? _get7DayChange(List<HealthEntry> entries, String Function(double) fmt) {
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

  Color _chartColor(BodyChartMetric m) {
    return switch (m) {
      BodyChartMetric.weight => AppColors.weightColor,
      BodyChartMetric.bodyFatPct => AppColors.fatColor,
      _ => AppColors.accentSecondary,
    };
  }

  Future<void> _openAdd() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddBodyCompositionScreen()),
    );
    if (changed == true) await _load();
  }

  Future<void> _openEdit(BodyCompositionEntry e) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddBodyCompositionScreen(existing: e)),
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
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.card,
                  hintText: 'Date\tWeight\tBody fat % …',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  try {
                    final list = parseBodyCompositionPaste(controller.text);
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
                'Body Metrics',
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
          if (_state != LoadState.loading) ...[
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
          if (_state == LoadState.loading)
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
    switch (_state) {
      case LoadState.idle:
      case LoadState.loading:
        return _buildLoadingState();
      case LoadState.denied:
        return _buildDeniedState();
      case LoadState.error:
        return _buildErrorState();
      case LoadState.loaded:
        return _buildLoadedState();
    }
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
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
        ],
      ),
    );
  }

  Widget _buildDeniedState() {
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
            'Allow health access to sync metrics, or add measurements manually.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _showImportSheet,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Import from clipboard'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _openAdd,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Add measurement'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _load,
            child: const Text('Try health access again'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
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

  Widget _buildLoadedState() {
    final weight = _metrics.latestWeight;
    final fat = _metrics.latestBodyFat;
    final chartOptions = metricsWithSeries(_entries).toList();
    final chartMetric = _selectedChartMetric;
    final series = chartMetric != null
        ? bodyCompositionSeries(_entries, chartMetric)
        : <HealthEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_entries.isEmpty) ...[
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_metrics.weightHistory.isNotEmpty ||
            _metrics.bodyFatHistory.isNotEmpty) ...[
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
                    subtitle: weight != null
                        ? _get7DayChange(_metrics.weightHistory, _formatWeight)
                        : null,
                    accentColor: AppColors.weightColor,
                    icon: Icons.monitor_weight_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Body Fat',
                    value: fat?.value.toStringAsFixed(1),
                    unit: '%',
                    subtitle: fat != null
                        ? _get7DayChange(
                            _metrics.bodyFatHistory, _formatFat)
                        : null,
                    accentColor: AppColors.fatColor,
                    icon: Icons.percent_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_entries.length >= 2) ...[
          const SizedBox(height: 20),
          BodyCompositionOverviewChart(entries: _entries),
        ],
        if (chartOptions.length > 1) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Trend',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: chartOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final m = chartOptions[i];
                final selected = chartMetric == m;
                return FilterChip(
                  label: Text(m.label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _selectedChartMetric = m);
                  },
                  selectedColor: _chartColor(m).withValues(alpha: 0.25),
                  checkmarkColor: _chartColor(m),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  side: BorderSide(
                    color: selected ? _chartColor(m) : AppColors.divider,
                  ),
                  backgroundColor: AppColors.card,
                );
              },
            ),
          ),
        ],
        if (series.length >= 2 && chartMetric != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              chartMetric.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          TrendChart(
            entries: series,
            color: _chartColor(chartMetric),
            unit: chartMetric.unit,
          ),
        ],
        if (_metrics.weightHistory.length >= 2 &&
            _entries.length < 2 &&
            (chartOptions.isEmpty ||
                chartMetric != BodyChartMetric.weight)) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Weight Trend',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 12),
          TrendChart(
            entries: _metrics.weightHistory,
            color: AppColors.weightColor,
            unit: 'kg',
          ),
        ],
        if (_metrics.bodyFatHistory.length >= 2 &&
            !(_entries.length >= 2 &&
                _entries.any((e) => e.bodyFatPct != null)) &&
            (chartOptions.isEmpty ||
                chartMetric != BodyChartMetric.bodyFatPct)) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Body Fat Trend',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 12),
          TrendChart(
            entries: _metrics.bodyFatHistory,
            color: AppColors.fatColor,
            unit: '%',
          ),
        ],
        if (_metrics.weightHistory.isNotEmpty) ...[
          const SizedBox(height: 28),
          HistorySection(
            title: 'Weight History',
            entries: _metrics.weightHistory,
            accentColor: AppColors.weightColor,
            formatter: _formatWeight,
          ),
        ],
        if (_metrics.bodyFatHistory.isNotEmpty) ...[
          const SizedBox(height: 28),
          HistorySection(
            title: 'Body Fat History',
            entries: _metrics.bodyFatHistory,
            accentColor: AppColors.fatColor,
            formatter: _formatFat,
          ),
        ],
        if (_entries.isNotEmpty) ...[
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Measurements',
              style: Theme.of(context).textTheme.titleLarge,
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
              itemCount: _entries.length > 20 ? 20 : _entries.length,
              separatorBuilder: (_, __) => const Divider(
                color: AppColors.divider,
                height: 1,
                indent: 16,
              ),
              itemBuilder: (context, index) {
                final reversed = [..._entries.reversed];
                final e = reversed[index];
                return ListTile(
                  title: Text(
                    '${e.weightKg.toStringAsFixed(2)} kg'
                    '${e.bodyFatPct != null ? ' · ${e.bodyFatPct!.toStringAsFixed(1)}% fat' : ''}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat.yMMMd().format(e.dateOnly),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                  onTap: () => _openEdit(e),
                );
              },
            ),
          ),
          if (_entries.length > 20)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Showing 20 most recent',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}
