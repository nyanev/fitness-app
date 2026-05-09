import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';
import '../theme/app_theme.dart';

class AddExerciseScreen extends StatefulWidget {
  final String templateId;

  const AddExerciseScreen({super.key, required this.templateId});

  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  final _service = WorkoutService.instance;
  final _searchController = TextEditingController();
  List<Exercise> _allExercises = [];
  List<Exercise> _filteredExercises = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final exercises = await _service.getExercises();
    if (mounted) {
      setState(() {
        _allExercises = exercises;
        _filteredExercises = exercises;
        _loading = false;
      });
    }
  }

  void _filter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredExercises = _allExercises
          .where(
            (e) =>
                e.name.toLowerCase().contains(query) ||
                (e.muscleGroup?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    });
  }

  Future<void> _showConfigSheet(Exercise exercise) async {
    int sets = 3;
    int reps = 10;
    double? weight;
    int restSeconds = 60;
    final weightController = TextEditingController();

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
                          exercise.name,
                          style: Theme.of(ctx).textTheme.titleLarge,
                        ),
                        if (exercise.muscleGroup != null)
                          Text(
                            exercise.muscleGroup!,
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
                    await _service.addExerciseToTemplate(
                      templateId: widget.templateId,
                      exerciseId: exercise.id,
                      exerciseName: exercise.name,
                      muscleGroup: exercise.muscleGroup,
                      sets: sets,
                      reps: reps,
                      weight: weight,
                      restSeconds: restSeconds,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Add to Workout',
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

  Map<String, List<Exercise>> _groupByMuscle() {
    final grouped = <String, List<Exercise>>{};
    for (final e in _filteredExercises) {
      grouped.putIfAbsent(e.muscleGroup ?? 'Other', () => []).add(e);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Add Exercise',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search exercises…',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : _buildExerciseList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseList() {
    if (_filteredExercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'No exercises found',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (_searchController.text.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        itemCount: _filteredExercises.length,
        itemBuilder: (_, i) => _buildExerciseTile(_filteredExercises[i]),
      );
    }

    final grouped = _groupByMuscle();
    final groups = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: groups.length,
      itemBuilder: (_, index) {
        final group = groups[index];
        final exercises = grouped[group]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                group.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...exercises.map(_buildExerciseTile),
          ],
        );
      },
    );
  }

  Widget _buildExerciseTile(Exercise exercise) {
    return GestureDetector(
      onTap: () => _showConfigSheet(exercise),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: AppColors.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  if (exercise.muscleGroup != null)
                    Text(
                      exercise.muscleGroup!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.add_circle_outline,
              color: AppColors.accent,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared form widgets ────────────────────────────────────────────────────

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

  const _WeightField({
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
