import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';
import '../theme/app_theme.dart';
import 'add_exercise_screen.dart';
import 'active_workout_screen.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final String templateId;

  const WorkoutDetailScreen({super.key, required this.templateId});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final _service = WorkoutService.instance;
  WorkoutTemplate? _template;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final template = await _service.getWorkoutTemplate(widget.templateId);
    if (mounted) {
      setState(() {
        _template = template;
        _loading = false;
      });
    }
  }

  Future<void> _addExercise() async {
    final template = _template;
    if (template == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExerciseScreen(templateId: template.id),
      ),
    );
    _load();
  }

  Future<void> _editExercise(TemplateExercise te) async {
    int sets = te.sets;
    int reps = te.reps;
    double? weight = te.weight;
    int restSeconds = te.restSeconds;
    final weightController = TextEditingController(
      text: te.weight != null
          ? te.weight!
              .toStringAsFixed(te.weight! % 1 == 0 ? 0 : 1)
          : '',
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          te.exerciseName,
                          style: Theme.of(ctx).textTheme.titleLarge,
                        ),
                        if (te.muscleGroup != null)
                          Text(
                            te.muscleGroup!,
                            style: Theme.of(ctx).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StepperField(
                      label: 'Sets',
                      value: sets,
                      min: 1,
                      max: 10,
                      onChanged: (v) => setModalState(() => sets = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StepperField(
                      label: 'Reps',
                      value: reps,
                      min: 1,
                      max: 50,
                      onChanged: (v) => setModalState(() => reps = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _WeightField(
                      controller: weightController,
                      onChanged: (v) => weight = v,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _RestTimeSelector(
                      value: restSeconds,
                      onChanged: (v) => setModalState(() => restSeconds = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await _service.updateTemplateExercise(
                      te.id,
                      sets: sets,
                      reps: reps,
                      weight: weight,
                      clearWeight: weight == null,
                      restSeconds: restSeconds,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    weightController.dispose();
  }

  Future<void> _startWorkout() async {
    final template = _template;
    if (template == null) return;
    if (template.exercises.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add exercises first'),
          backgroundColor: AppColors.card,
        ),
      );
      return;
    }
    final session = await _service.startWorkoutSession(template);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutScreen(session: session),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  String _formatExerciseDetails(TemplateExercise te) {
    final parts = <String>['${te.sets} × ${te.reps} reps'];
    if (te.weight != null) {
      parts.add(
        '${te.weight!.toStringAsFixed(te.weight! % 1 == 0 ? 0 : 1)} kg',
      );
    }
    final mins = te.restSeconds ~/ 60;
    final secs = te.restSeconds % 60;
    if (mins > 0) {
      parts.add(secs > 0 ? '${mins}m ${secs}s rest' : '${mins}m rest');
    } else {
      parts.add('${secs}s rest');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    final template = _template;
    if (template == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'Workout not found',
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
        ),
        title: Text(
          template.name,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            onPressed: _addExercise,
            icon: const Icon(Icons.add_rounded, color: AppColors.accent),
            tooltip: 'Add exercise',
          ),
        ],
      ),
      body: template.exercises.isEmpty
          ? _buildEmptyExercises()
          : _buildExerciseList(template),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _startWorkout,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, size: 22),
                SizedBox(width: 8),
                Text(
                  'Start Workout',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyExercises() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_circle_outline,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 20),
            Text(
              'No exercises yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Add exercises to build your workout',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _addExercise,
              icon: const Icon(Icons.add),
              label: const Text('Add Exercise'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseList(WorkoutTemplate template) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: template.exercises.length,
      itemBuilder: (_, index) {
        final te = template.exercises[index];
        return Dismissible(
          key: Key(te.id),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade900,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          onDismissed: (_) async {
            await _service.removeExerciseFromTemplate(te.id);
            _load();
          },
          child: GestureDetector(
            onTap: () => _editExercise(te),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          te.exerciseName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatExerciseDetails(te),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Private helper widgets ────────────────────────────────────────────────

class _StepperField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _StepperField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

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
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
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

class _WeightField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<double?> onChanged;

  const _WeightField({required this.controller, required this.onChanged});

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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          onChanged: (v) => onChanged(double.tryParse(v)),
        ),
      ],
    );
  }
}

class _RestTimeSelector extends StatelessWidget {
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

  const _RestTimeSelector({required this.value, required this.onChanged});

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
              .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
