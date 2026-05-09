import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/health_entry.dart';
import '../theme/app_theme.dart';

class HealthMetricDetailScreen extends StatelessWidget {
  final String title;
  final List<HealthEntry> entries;
  final Color accentColor;
  final String unit;
  final String Function(double) formatter;

  const HealthMetricDetailScreen({
    super.key,
    required this.title,
    required this.entries,
    required this.accentColor,
    required this.unit,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final reversed = [...entries.reversed];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(title),
        foregroundColor: AppColors.textPrimary,
      ),
      body: reversed.isEmpty
          ? const Center(
              child: Text(
                'No data',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: reversed.length,
              separatorBuilder: (_, __) => const SizedBox(height: 1),
              itemBuilder: (context, index) {
                final e = reversed[index];
                final isFirst = index == 0;
                final delta = index < reversed.length - 1
                    ? e.value - reversed[index + 1].value
                    : null;

                return ListTile(
                  tileColor: AppColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: index == 0
                          ? const Radius.circular(16)
                          : Radius.zero,
                      bottom: index == reversed.length - 1
                          ? const Radius.circular(16)
                          : Radius.zero,
                    ),
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(
                          alpha: isFirst ? 0.2 : 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.circle,
                        color: accentColor
                            .withValues(alpha: isFirst ? 1.0 : 0.4),
                        size: 8),
                  ),
                  title: Text(
                    formatter(e.value),
                    style: TextStyle(
                      color: isFirst
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight:
                          isFirst ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat('EEE, MMM d, yyyy').format(e.date),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: delta != null && delta.abs() >= 0.01
                      ? _DeltaBadge(delta: delta, unit: unit)
                      : null,
                );
              },
            ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  final double delta;
  final String unit;

  const _DeltaBadge({required this.delta, required this.unit});

  @override
  Widget build(BuildContext context) {
    final isPositive = delta > 0;
    final color = isPositive ? Colors.redAccent : Colors.greenAccent;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPositive ? Icons.arrow_upward : Icons.arrow_downward,
          color: color,
          size: 12,
        ),
        const SizedBox(width: 2),
        Text(
          '${delta.abs().toStringAsFixed(1)} $unit',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class SleepDetailScreen extends StatelessWidget {
  final Map<DateTime, Duration> nightsByDate;

  const SleepDetailScreen({super.key, required this.nightsByDate});

  @override
  Widget build(BuildContext context) {
    final sorted = nightsByDate.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Sleep History'),
        foregroundColor: AppColors.textPrimary,
      ),
      body: sorted.isEmpty
          ? const Center(
              child: Text(
                'No sleep data',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 1),
              itemBuilder: (context, index) {
                final night = sorted[index];
                final isFirst = index == 0;
                return ListTile(
                  tileColor: AppColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: index == 0
                          ? const Radius.circular(16)
                          : Radius.zero,
                      bottom: index == sorted.length - 1
                          ? const Radius.circular(16)
                          : Radius.zero,
                    ),
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.sleepColor.withValues(
                          alpha: isFirst ? 0.2 : 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.bedtime_outlined,
                        color: AppColors.sleepColor
                            .withValues(alpha: isFirst ? 1.0 : 0.4),
                        size: 18),
                  ),
                  title: Text(
                    _formatDuration(night.value),
                    style: TextStyle(
                      color: isFirst
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight:
                          isFirst ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat('EEE, MMM d, yyyy').format(night.key),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class BloodPressureDetailScreen extends StatelessWidget {
  final List<BloodPressureEntry> readings;

  const BloodPressureDetailScreen({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    final sorted = [...readings]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Blood Pressure History'),
        foregroundColor: AppColors.textPrimary,
      ),
      body: sorted.isEmpty
          ? const Center(
              child: Text(
                'No data',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 1),
              itemBuilder: (context, index) {
                final r = sorted[index];
                final isFirst = index == 0;
                return ListTile(
                  tileColor: AppColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: index == 0
                          ? const Radius.circular(16)
                          : Radius.zero,
                      bottom: index == sorted.length - 1
                          ? const Radius.circular(16)
                          : Radius.zero,
                    ),
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(
                          alpha: isFirst ? 0.2 : 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.water_drop_outlined,
                        color: AppColors.accent
                            .withValues(alpha: isFirst ? 1.0 : 0.4),
                        size: 18),
                  ),
                  title: Text(
                    '${r.systolic.toStringAsFixed(0)} / ${r.diastolic.toStringAsFixed(0)} mmHg',
                    style: TextStyle(
                      color: isFirst
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight:
                          isFirst ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  subtitle: Text(
                    '${DateFormat('EEE, MMM d, yyyy').format(r.date)}  ·  ${_bpCategory(r.systolic, r.diastolic)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
    );
  }

  String _bpCategory(double sys, double dia) {
    if (sys < 120 && dia < 80) return 'Normal';
    if (sys < 130 && dia < 80) return 'Elevated';
    if (sys < 140 || dia < 90) return 'High Stage 1';
    return 'High Stage 2';
  }
}
