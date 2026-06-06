import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Labelled +/- stepper with a tappable value that opens a numeric entry
/// dialog. Used for sets/reps in the exercise config and edit sheets.
class StepperField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const StepperField({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  Future<void> _pickValue(BuildContext context) async {
    final controller = TextEditingController(text: '$value');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(label,
            style: const TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onSubmitted: (v) {
            final n = int.tryParse(v);
            if (n != null) Navigator.pop(ctx, n.clamp(min, max));
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              if (n != null) Navigator.pop(ctx, n.clamp(min, max));
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: value > min ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove, size: 18),
                color: AppColors.textPrimary,
                disabledColor: AppColors.textSecondary,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickValue(context),
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: value < max ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add, size: 18),
                color: AppColors.textPrimary,
                disabledColor: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Optional decimal weight (kg) input field.
class WeightField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<double?> onChanged;

  const WeightField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weight (kg)',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Optional',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            suffixText: 'kg',
            suffixStyle: const TextStyle(color: AppColors.textSecondary),
          ),
          onChanged: (v) => onChanged(double.tryParse(v.replaceAll(',', '.'))),
        ),
      ],
    );
  }
}

/// Rest-time dropdown selector with a fixed set of common durations.
class RestTimeSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  static const _options = [
    (30, '30s'),
    (45, '45s'),
    (60, '1 min'),
    (90, '1m 30s'),
    (120, '2 min'),
    (180, '3 min'),
  ];

  const RestTimeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentValue =
        _options.any((o) => o.$1 == value) ? value : _options[2].$1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rest Time',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: currentValue,
          dropdownColor: AppColors.card,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          items: _options
              .map(
                (o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
