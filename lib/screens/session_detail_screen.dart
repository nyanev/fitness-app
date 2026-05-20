import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';
import '../theme/app_theme.dart';

class SessionDetailScreen extends StatefulWidget {
  final WorkoutSession session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _service = WorkoutService.instance;
  late List<List<SetResult>> _sets;

  @override
  void initState() {
    super.initState();
    _sets = widget.session.exercises
        .map((e) => List<SetResult>.from(e.completedSets))
        .toList();
  }

  int get _totalSetsCompleted => _sets.fold(0, (sum, s) => sum + s.length);
  double get _totalVolume => _sets.fold(
        0.0,
        (sum, sets) =>
            sum + sets.fold(0.0, (s, r) => s + r.weight * r.reps),
      );

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    if (m < 60) return '${m}m';
    final h = d.inHours;
    final rem = m - h * 60;
    return rem > 0 ? '${h}h ${rem}m' : '${h}h';
  }

  Future<void> _editSet(int exerciseIdx, int setIdx) async {
    final set = _sets[exerciseIdx][setIdx];
    final weightCtrl = TextEditingController(
      text: set.weight > 0
          ? set.weight.toStringAsFixed(set.weight % 1 == 0 ? 0 : 1)
          : '',
    );
    final repsCtrl = TextEditingController(text: '${set.reps}');

    final saved = await _showSetDialog(
      title: 'Edit Set ${setIdx + 1}',
      weightCtrl: weightCtrl,
      repsCtrl: repsCtrl,
    );

    weightCtrl.dispose();
    repsCtrl.dispose();
    if (saved != true) return;

    final newWeight = double.tryParse(weightCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    final newReps = int.tryParse(repsCtrl.text.trim()) ?? set.reps;
    if (newReps <= 0) return;

    await _service.updateSetResult(set.id, reps: newReps, weight: newWeight);
    setState(() {
      _sets[exerciseIdx][setIdx] = SetResult(
        id: set.id,
        sessionExerciseId: set.sessionExerciseId,
        setNumber: set.setNumber,
        reps: newReps,
        weight: newWeight,
        completedAt: set.completedAt,
      );
    });
  }

  Future<void> _deleteSet(int exerciseIdx, int setIdx) async {
    final set = _sets[exerciseIdx][setIdx];
    await _service.deleteSetResult(set.id);
    setState(() => _sets[exerciseIdx].removeAt(setIdx));
  }

  Future<void> _addSet(int exerciseIdx) async {
    final exercise = widget.session.exercises[exerciseIdx];
    final existing = _sets[exerciseIdx];
    final last = existing.isNotEmpty ? existing.last : null;

    final weightCtrl = TextEditingController(
      text: last != null && last.weight > 0
          ? last.weight.toStringAsFixed(last.weight % 1 == 0 ? 0 : 1)
          : (exercise.targetWeight != null && exercise.targetWeight! > 0
              ? exercise.targetWeight!
                  .toStringAsFixed(exercise.targetWeight! % 1 == 0 ? 0 : 1)
              : ''),
    );
    final repsCtrl = TextEditingController(
      text: '${last?.reps ?? exercise.targetReps}',
    );

    final saved = await _showSetDialog(
      title: 'Add Set ${existing.length + 1}',
      weightCtrl: weightCtrl,
      repsCtrl: repsCtrl,
    );

    weightCtrl.dispose();
    repsCtrl.dispose();
    if (saved != true) return;

    final newWeight = double.tryParse(weightCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    final newReps =
        int.tryParse(repsCtrl.text.trim()) ?? exercise.targetReps;
    if (newReps <= 0) return;

    final result = await _service.recordSet(
      sessionExerciseId: exercise.id,
      setNumber: existing.length + 1,
      reps: newReps,
      weight: newWeight,
    );
    setState(() => _sets[exerciseIdx].add(result));
  }

  Future<bool?> _showSetDialog({
    required String title,
    required TextEditingController weightCtrl,
    required TextEditingController repsCtrl,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(
              controller: weightCtrl,
              label: 'Weight (kg)',
              decimal: true,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            _dialogField(
              controller: repsCtrl,
              label: 'Reps',
              decimal: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required bool decimal,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.session.duration;

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
          widget.session.templateName,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSummaryCard(context, duration),
          const SizedBox(height: 24),
          Text(
            'Exercises',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...widget.session.exercises.asMap().entries.map(
                (entry) => _buildExerciseCard(context, entry.key, entry.value),
              ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, Duration? duration) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(
            context,
            label: 'Date',
            value: DateFormat('MMM d').format(widget.session.startedAt),
          ),
          _buildDivider(),
          _buildStat(
            context,
            label: 'Duration',
            value: duration != null ? _formatDuration(duration) : '—',
          ),
          _buildDivider(),
          _buildStat(
            context,
            label: 'Sets',
            value: '$_totalSetsCompleted',
          ),
          _buildDivider(),
          _buildStat(
            context,
            label: 'Volume',
            value: '${_totalVolume.toStringAsFixed(0)} kg',
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 40, color: AppColors.divider);
  }

  Widget _buildStat(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildExerciseCard(
    BuildContext context,
    int exerciseIdx,
    SessionExercise exercise,
  ) {
    final sets = _sets[exerciseIdx];
    final totalVolume =
        sets.fold(0.0, (sum, s) => sum + s.weight * s.reps);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exercise.exerciseName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              if (totalVolume > 0)
                Text(
                  '${totalVolume.toStringAsFixed(0)} kg total',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (sets.isEmpty)
            const Text(
              'No sets completed',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          else
            ...sets.asMap().entries.map(
                  (entry) => _buildSetRow(exerciseIdx, entry.key, entry.value),
                ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _addSet(exerciseIdx),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Set'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(int exerciseIdx, int setIdx, SetResult set) {
    return Dismissible(
      key: ValueKey(set.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
      ),
      onDismissed: (_) => _deleteSet(exerciseIdx, setIdx),
      child: InkWell(
        onTap: () => _editSet(exerciseIdx, setIdx),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withValues(alpha: 0.15),
                ),
                child: Center(
                  child: Text(
                    '${setIdx + 1}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  set.weight > 0
                      ? '${set.weight.toStringAsFixed(set.weight % 1 == 0 ? 0 : 1)} kg  ×  ${set.reps} reps'
                      : '${set.reps} reps',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              if (set.weight > 0)
                Text(
                  '${(set.weight * set.reps).toStringAsFixed(0)} kg',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(
                Icons.edit_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
