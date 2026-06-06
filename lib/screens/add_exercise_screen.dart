import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';
import '../theme/app_theme.dart';
import '../widgets/workout_form_fields.dart';

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
                    child: StepperField(
                      label: 'Sets',
                      value: sets,
                      min: 1,
                      max: 10,
                      onChanged: (v) => setModalState(() => sets = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StepperField(
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
                    child: WeightField(
                      controller: weightController,
                      onChanged: (v) => weight = v,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: RestTimeSelector(
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

  Future<void> _showCreateExerciseSheet() async {
    final created = await showModalBottomSheet<Exercise>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateExerciseSheet(service: _service),
    );

    if (created != null && mounted) {
      await _load();
      await _showConfigSheet(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateExerciseSheet,
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Custom'),
      ),
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

  static IconData _iconForMuscleGroup(String? group) {
    switch (group?.toLowerCase()) {
      case 'chest':
        return Icons.sports_handball_rounded;
      case 'back':
        return Icons.rowing_rounded;
      case 'legs':
        return Icons.directions_run_rounded;
      case 'shoulders':
        return Icons.sports_volleyball_rounded;
      case 'biceps':
      case 'triceps':
        return Icons.fitness_center_rounded;
      case 'core':
        return Icons.self_improvement_rounded;
      case 'cardio':
        return Icons.favorite_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  static Color _colorForMuscleGroup(String? group) {
    switch (group?.toLowerCase()) {
      case 'chest':
        return AppColors.muscleChest;
      case 'back':
        return AppColors.muscleBack;
      case 'legs':
        return AppColors.muscleLegs;
      case 'shoulders':
        return AppColors.muscleShoulders;
      case 'biceps':
        return AppColors.muscleBiceps;
      case 'triceps':
        return AppColors.muscleTriceps;
      case 'core':
        return AppColors.muscleCore;
      case 'cardio':
        return AppColors.muscleCardio;
      default:
        return AppColors.accent;
    }
  }

  Widget _buildExerciseTile(Exercise exercise) {
    final iconColor = _colorForMuscleGroup(exercise.muscleGroup);
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
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconForMuscleGroup(exercise.muscleGroup),
                color: iconColor,
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

// ── Create custom exercise sheet ──────────────────────────────────────────

class _CreateExerciseSheet extends StatefulWidget {
  final WorkoutService service;
  const _CreateExerciseSheet({required this.service});

  @override
  State<_CreateExerciseSheet> createState() => _CreateExerciseSheetState();
}

class _CreateExerciseSheetState extends State<_CreateExerciseSheet> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedGroup;

  static const _muscleGroups = [
    'Chest', 'Back', 'Legs', 'Shoulders',
    'Biceps', 'Triceps', 'Core', 'Cardio', 'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'New Exercise',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Exercise name',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedGroup,
              dropdownColor: AppColors.card,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Muscle group (optional)',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              items: _muscleGroups
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedGroup = v),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final nav = Navigator.of(context);
                  final exercise = await widget.service.createExercise(
                    _nameController.text.trim(),
                    muscleGroup: _selectedGroup,
                  );
                  if (mounted) nav.pop(exercise);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Create Exercise',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

