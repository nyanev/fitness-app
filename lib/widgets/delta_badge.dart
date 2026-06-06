import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small arrow + value badge showing the change between two consecutive
/// readings. An increase is treated as "bad" (red), a decrease as "good"
/// (green) — matching weight/body-fat semantics.
class DeltaBadge extends StatelessWidget {
  final double delta;
  final String unit;

  /// Whether to insert a space between the value and the unit
  /// (e.g. `2.0 kg` vs `2.0%`).
  final bool spaceBeforeUnit;

  const DeltaBadge({
    super.key,
    required this.delta,
    required this.unit,
    this.spaceBeforeUnit = false,
  });

  @override
  Widget build(BuildContext context) {
    if (delta.abs() < 0.01) return const SizedBox.shrink();

    final isPositive = delta > 0;
    final color = isPositive
        ? AppColors.deltaPositiveColor
        : AppColors.deltaNegativeColor;
    final separator = spaceBeforeUnit ? ' ' : '';

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
          '${delta.abs().toStringAsFixed(1)}$separator$unit',
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
