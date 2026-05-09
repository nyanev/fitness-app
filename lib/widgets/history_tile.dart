import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/health_entry.dart';
import '../theme/app_theme.dart';

class HistorySection extends StatelessWidget {
  final String title;
  final List<HealthEntry> entries;
  final Color accentColor;
  final String Function(double) formatter;

  const HistorySection({
    super.key,
    required this.title,
    required this.entries,
    required this.accentColor,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final reversed = entries.reversed.take(30).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            title,
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
            itemCount: reversed.length,
            separatorBuilder: (_, __) => Divider(
              color: AppColors.divider,
              height: 1,
              indent: 56,
            ),
            itemBuilder: (context, index) {
              final entry = reversed[index];
              final isFirst = index == 0;
              final delta = index < reversed.length - 1
                  ? entry.value - reversed[index + 1].value
                  : null;

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isFirst ? 0.2 : 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.circle,
                    color: accentColor.withValues(alpha: isFirst ? 1.0 : 0.4),
                    size: 8,
                  ),
                ),
                title: Text(
                  formatter(entry.value),
                  style: TextStyle(
                    color: isFirst
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight:
                        isFirst ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  DateFormat('EEE, MMM d, yyyy').format(entry.date),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: delta != null
                    ? _DeltaBadge(delta: delta, unit: entry.unit)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  final double delta;
  final String unit;

  const _DeltaBadge({required this.delta, required this.unit});

  @override
  Widget build(BuildContext context) {
    if (delta.abs() < 0.01) return const SizedBox.shrink();

    final isPositive = delta > 0;
    final color = unit == '%'
        ? (isPositive ? Colors.redAccent : Colors.greenAccent)
        : (isPositive ? Colors.redAccent : Colors.greenAccent);

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
          '${delta.abs().toStringAsFixed(1)}$unit',
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
