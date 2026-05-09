import 'package:flutter/material.dart';
import '../models/health_entry.dart';
import '../theme/app_theme.dart';

class TrendChart extends StatelessWidget {
  final List<HealthEntry> entries;
  final Color color;
  final String unit;

  const TrendChart({
    super.key,
    required this.entries,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) return const SizedBox.shrink();

    final recent = entries.length > 30
        ? entries.sublist(entries.length - 30)
        : entries;

    final minVal = recent.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    final maxVal = recent.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${recent.length}-day trend',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                unit.isEmpty
                    ? '${minVal.toStringAsFixed(1)} – ${maxVal.toStringAsFixed(1)}'
                    : '${minVal.toStringAsFixed(1)} – ${maxVal.toStringAsFixed(1)} $unit',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 60,
            child: CustomPaint(
              size: const Size(double.infinity, 60),
              painter: _LinePainter(
                entries: recent,
                color: color,
                minVal: range < 0.001 ? minVal - 1 : minVal,
                maxVal: range < 0.001 ? maxVal + 1 : maxVal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<HealthEntry> entries;
  final Color color;
  final double minVal;
  final double maxVal;

  _LinePainter({
    required this.entries,
    required this.color,
    required this.minVal,
    required this.maxVal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    final range = maxVal - minVal;
    final points = <Offset>[];

    for (int i = 0; i < entries.length; i++) {
      final x = i / (entries.length - 1) * size.width;
      final normalised = range == 0
          ? 0.5
          : 1.0 - (entries[i].value - minVal) / range;
      final y = normalised * size.height;
      points.add(Offset(x, y));
    }

    // Fill gradient under line
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final pt in points) {
      fillPath.lineTo(pt.dx, pt.dy);
    }
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Draw line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final cp1 = Offset((prev.dx + curr.dx) / 2, prev.dy);
      final cp2 = Offset((prev.dx + curr.dx) / 2, curr.dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Draw last point dot
    canvas.drawCircle(
      points.last,
      4,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.entries != entries || old.color != color;
}
