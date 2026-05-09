import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../models/body_composition_entry.dart';
import '../theme/app_theme.dart';

/// Overview chart: RGB primaries for clear distinction on dark background.
const Color _chartWeightBlue = Color(0xFF448AFF);
const Color _chartFatRed = Color(0xFFFF5252);
const Color _chartMuscleGreen = Color(0xFF69F0AE);

/// Overlays weight (kg), body fat %, and skeletal muscle (kg if any row has kg,
/// otherwise %) on one chart. Each series is scaled to its own min–max in the
/// visible window so shapes are comparable; see legend for real values.
class BodyCompositionOverviewChart extends StatelessWidget {
  final List<BodyCompositionEntry> entries;

  const BodyCompositionOverviewChart({
    super.key,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) return const SizedBox.shrink();

    final sorted = [...entries]..sort((a, b) => a.dateOnly.compareTo(b.dateOnly));
    final window = sorted.length > 30
        ? sorted.sublist(sorted.length - 30)
        : sorted;
    final n = window.length;
    if (n < 2) return const SizedBox.shrink();

    final useMuscleKg =
        window.any((e) => e.skeletalMuscleMassKg != null);

    final weightVals = window.map<double?>((e) => e.weightKg).toList();
    final fatVals = window.map((e) => e.bodyFatPct).toList();
    final muscleVals = window
        .map(
          (e) => useMuscleKg ? e.skeletalMuscleMassKg : e.skeletalMuscleMassPct,
        )
        .toList();

    final seriesList = <_Series>[
      _Series.fromValues(
        label: 'Weight',
        unit: 'kg',
        color: _chartWeightBlue,
        values: weightVals,
      ),
      if (fatVals.any((v) => v != null))
        _Series.fromValues(
          label: 'Body fat',
          unit: '%',
          color: _chartFatRed,
          values: fatVals,
        ),
      if (muscleVals.any((v) => v != null))
        _Series.fromValues(
          label: useMuscleKg ? 'Muscle (kg)' : 'Muscle (%)',
          unit: useMuscleKg ? 'kg' : '%',
          color: _chartMuscleGreen,
          values: muscleVals,
        ),
    ];

    final drawable =
        seriesList.where((s) => s.nonNullCount >= 2).toList(growable: false);
    if (drawable.isEmpty) return const SizedBox.shrink();

    final firstDay = window.first.dateOnly;
    final lastDay = window.last.dateOnly;
    final midDay = n >= 3 ? window[n ~/ 2].dateOnly : null;

    final axisLabelStyle = TextStyle(
      color: AppColors.textSecondary.withValues(alpha: 0.95),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weight, fat & muscle',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            "Each line uses its own scale (compare shape; values in legend). "
            "Y axis: 0–100% of each line's range in this window.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 168,
            width: double.infinity,
            child: CustomPaint(
              painter: _OverviewChartPainter(
                series: drawable,
                pointCount: n,
                firstDate: firstDay,
                midDate: midDay,
                lastDate: lastDay,
                axisLabelStyle: axisLabelStyle,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final s in drawable)
                _LegendItem(series: s),
            ],
          ),
        ],
      ),
    );
  }
}

class _Series {
  _Series({
    required this.label,
    required this.unit,
    required this.color,
    required this.values,
    required this.minVal,
    required this.maxVal,
  });

  final String label;
  final String unit;
  final Color color;
  final List<double?> values;
  final double minVal;
  final double maxVal;

  int get nonNullCount => values.whereType<double>().length;

  factory _Series.fromValues({
    required String label,
    required String unit,
    required Color color,
    required List<double?> values,
  }) {
    final present = values.whereType<double>().toList();
    var minV = present.isEmpty ? 0.0 : present.reduce((a, b) => a < b ? a : b);
    var maxV = present.isEmpty ? 1.0 : present.reduce((a, b) => a > b ? a : b);
    if ((maxV - minV).abs() < 1e-9) {
      minV = minV - 1;
      maxV = maxV + 1;
    }
    return _Series(
      label: label,
      unit: unit,
      color: color,
      values: values,
      minVal: minV,
      maxVal: maxV,
    );
  }

  double? normalizedY(int i, double plotHeight) {
    final v = i < values.length ? values[i] : null;
    if (v == null) return null;
    final range = maxVal - minVal;
    final t = range == 0 ? 0.5 : (v - minVal) / range;
    return (1.0 - t) * plotHeight;
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.series});

  final _Series series;

  @override
  Widget build(BuildContext context) {
    final r = '${series.minVal.toStringAsFixed(1)}–${series.maxVal.toStringAsFixed(1)}';
    final u = series.unit.isEmpty ? '' : ' ${series.unit}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: series.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${series.label}: $r$u',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _OverviewChartPainter extends CustomPainter {
  _OverviewChartPainter({
    required this.series,
    required this.pointCount,
    required this.firstDate,
    required this.midDate,
    required this.lastDate,
    required this.axisLabelStyle,
  });

  final List<_Series> series;
  final int pointCount;
  final DateTime firstDate;
  final DateTime? midDate;
  final DateTime lastDate;
  final TextStyle axisLabelStyle;

  static const double _leftPad = 40;
  static const double _rightPad = 10;
  static const double _topPad = 6;
  static const double _bottomPad = 34;

  @override
  void paint(Canvas canvas, Size size) {
    if (pointCount < 2) return;

    final plot = Rect.fromLTWH(
      _leftPad,
      _topPad,
      size.width - _leftPad - _rightPad,
      size.height - _topPad - _bottomPad,
    );

    final gridPaint = Paint()
      ..color = AppColors.divider.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.55)
      ..strokeWidth = 1.5;

    // Horizontal grid + Y labels (normalized 0–100 for each series’ window)
    const yLabels = ['100', '50', '0'];
    for (var i = 0; i < 3; i++) {
      final frac = i / 2.0;
      final y = plot.top + frac * plot.height;
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        gridPaint,
      );
      final tp = TextPainter(
        text: TextSpan(text: yLabels[i], style: axisLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          plot.left - tp.width - 8,
          y - tp.height / 2,
        ),
      );
    }

    // Vertical grid at 1/3 and 2/3 of the time window
    for (final vx in [1 / 3.0, 2 / 3.0]) {
      final x = plot.left + vx * plot.width;
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        gridPaint,
      );
    }

    // X and Y axes (along plot edges)
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);
    canvas.drawLine(plot.bottomLeft, plot.topLeft, axisPaint);

    // Data lines
    final w = plot.width;
    final h = plot.height;
    for (final s in series) {
      var segment = <Offset>[];
      for (int i = 0; i < pointCount; i++) {
        final ny = s.normalizedY(i, h);
        final x = plot.left + i / (pointCount - 1) * w;
        if (ny != null) {
          segment.add(Offset(x, plot.top + ny));
        } else {
          _paintSegment(canvas, segment, s.color);
          segment = [];
        }
      }
      _paintSegment(canvas, segment, s.color);
    }

    // X axis date labels
    final dateFmt = intl.DateFormat.MMMd();
    _paintXLabel(canvas, plot, dateFmt.format(firstDate), 0.0);
    if (midDate != null && pointCount >= 3) {
      _paintXLabel(canvas, plot, dateFmt.format(midDate!), 0.5);
    }
    _paintXLabel(canvas, plot, dateFmt.format(lastDate), 1.0);
  }

  void _paintXLabel(Canvas canvas, Rect plot, String text, double xFrac) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: axisLabelStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: plot.width * 0.45);
    final cx = plot.left + xFrac * plot.width - tp.width / 2;
    final maxX = plot.right - tp.width;
    final labelX = maxX >= plot.left ? cx.clamp(plot.left, maxX) : plot.left;
    tp.paint(canvas, Offset(labelX, plot.bottom + 6));
  }

  static void _paintSegment(Canvas canvas, List<Offset> segment, Color color) {
    if (segment.length >= 2) {
      final linePath = Path()..moveTo(segment.first.dx, segment.first.dy);
      for (int i = 1; i < segment.length; i++) {
        final prev = segment[i - 1];
        final curr = segment[i];
        final cp1 = Offset((prev.dx + curr.dx) / 2, prev.dy);
        final cp2 = Offset((prev.dx + curr.dx) / 2, curr.dy);
        linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color = color
          ..strokeWidth = 2.75
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawCircle(segment.last, 4.5, Paint()..color = color);
    } else if (segment.length == 1) {
      canvas.drawCircle(segment.single, 4.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _OverviewChartPainter old) =>
      old.pointCount != pointCount ||
      old.series.length != series.length ||
      old.firstDate != firstDate ||
      old.lastDate != lastDate ||
      old.midDate != midDate;
}
