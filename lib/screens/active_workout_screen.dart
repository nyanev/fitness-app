import 'dart:async';
import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/health_service.dart';
import '../services/workout_service.dart';
import '../theme/app_theme.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final WorkoutSession session;

  const ActiveWorkoutScreen({super.key, required this.session});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final _service = WorkoutService.instance;

  late final List<SessionExercise> _exercises;
  late final List<List<SetResult>> _completedSets;
  int _currentExerciseIndex = 0;

  bool _isResting = false;
  int _restSecondsLeft = 0;
  int _restTotalSeconds = 0;
  Timer? _restTimer;

  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  late TextEditingController _weightController;
  late TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _exercises = List.from(widget.session.exercises);
    _completedSets =
        _exercises.map((e) => List<SetResult>.from(e.completedSets)).toList();
    _elapsed = DateTime.now().difference(widget.session.startedAt);
    _initInputControllers();
    _startElapsedTimer();
  }

  void _initInputControllers() {
    final exercise = _currentExercise;
    _weightController = TextEditingController(
      text: exercise.targetWeight != null
          ? exercise.targetWeight!
              .toStringAsFixed(exercise.targetWeight! % 1 == 0 ? 0 : 1)
          : '',
    );
    _repsController = TextEditingController(
      text: '${exercise.targetReps}',
    );
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(
          () => _elapsed = DateTime.now().difference(widget.session.startedAt),
        );
      }
    });
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _elapsedTimer?.cancel();
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  SessionExercise get _currentExercise => _exercises[_currentExerciseIndex];
  List<SetResult> get _currentCompletedSets =>
      _completedSets[_currentExerciseIndex];
  int get _currentSetNumber => _currentCompletedSets.length + 1;
  bool get _isCurrentExerciseComplete =>
      _currentCompletedSets.length >= _currentExercise.targetSets;
  bool get _isLastExercise =>
      _currentExerciseIndex == _exercises.length - 1;
  int get _totalSetsCompleted =>
      _completedSets.fold(0, (sum, sets) => sum + sets.length);

  Future<void> _logSet() async {
    final weightText = _weightController.text.trim();
    final repsText = _repsController.text.trim();
    final weight = double.tryParse(weightText) ?? 0.0;
    final reps = int.tryParse(repsText);

    if (reps == null || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid number of reps'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await _service.recordSet(
      sessionExerciseId: _currentExercise.id,
      setNumber: _currentSetNumber,
      reps: reps,
      weight: weight,
    );

    setState(() {
      _completedSets[_currentExerciseIndex].add(result);
    });

    if (!_isCurrentExerciseComplete) {
      _startRestTimer();
    }
  }

  void _startRestTimer() {
    final restSeconds = _currentExercise.restSeconds;
    _restTimer?.cancel();
    setState(() {
      _isResting = true;
      _restSecondsLeft = restSeconds;
      _restTotalSeconds = restSeconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _restSecondsLeft--;
        if (_restSecondsLeft <= 0) {
          _isResting = false;
          timer.cancel();
        }
      });
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restSecondsLeft = 0;
    });
  }

  void _adjustRest(int delta) {
    setState(() {
      _restSecondsLeft = (_restSecondsLeft + delta).clamp(0, 3600);
      if (_restSecondsLeft > _restTotalSeconds) {
        _restTotalSeconds = _restSecondsLeft;
      }
    });
  }

  void _nextExercise() {
    if (_isLastExercise) return;
    _restTimer?.cancel();
    setState(() {
      _currentExerciseIndex++;
      _isResting = false;
      _restSecondsLeft = 0;
    });
    final exercise = _currentExercise;
    _weightController.text = exercise.targetWeight != null
        ? exercise.targetWeight!
            .toStringAsFixed(exercise.targetWeight! % 1 == 0 ? 0 : 1)
        : '';
    _repsController.text = '${exercise.targetReps}';
  }

  Future<void> _finishWorkout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Finish Workout?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '${_formatDuration(_elapsed)} elapsed  ·  $_totalSetsCompleted sets completed',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Continue',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            child: const Text('Finish'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _restTimer?.cancel();
    _elapsedTimer?.cancel();
    final completed = await _service.completeSession(widget.session.id);
    HealthService().writeCompletedWorkout(completed);
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _confirmAbandon() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Abandon Workout?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Your progress will not be saved to history.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Continue',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.abandonSession(widget.session.id);
      return true;
    }
    return false;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldPop = await _confirmAbandon();
          if (shouldPop && context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(child: _buildBody()),
            if (_isResting) _buildRestBanner(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        onPressed: () async {
          final shouldPop = await _confirmAbandon();
          if (shouldPop && mounted) Navigator.pop(context);
        },
        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
      ),
      title: Column(
        children: [
          Text(
            _currentExercise.exerciseName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            _formatDuration(_elapsed),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: _finishWorkout,
          child: const Text(
            'Finish',
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressIndicator(),
          const SizedBox(height: 24),
          _buildExerciseHeader(),
          const SizedBox(height: 20),
          _buildSetsList(),
          const SizedBox(height: 20),
          if (!_isCurrentExerciseComplete)
            _buildInputArea()
          else
            _buildExerciseCompleteActions(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final setProgress = _currentExercise.targetSets > 0
        ? _currentCompletedSets.length / _currentExercise.targetSets
        : 0.0;
    final overallProgress = _exercises.isNotEmpty
        ? (_currentExerciseIndex + setProgress) / _exercises.length
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Exercise ${_currentExerciseIndex + 1} of ${_exercises.length}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${_currentCompletedSets.length} / ${_currentExercise.targetSets} sets',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: overallProgress,
            backgroundColor: AppColors.card,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseHeader() {
    final exercise = _currentExercise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exercise.exerciseName,
          style: Theme.of(context)
              .textTheme
              .displayMedium
              ?.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 6),
        Text(
          [
            '${exercise.targetSets} sets × ${exercise.targetReps} reps',
            if (exercise.targetWeight != null)
              '${exercise.targetWeight!.toStringAsFixed(exercise.targetWeight! % 1 == 0 ? 0 : 1)} kg',
          ].join(' · '),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildSetsList() {
    final exercise = _currentExercise;
    final completedSets = _currentCompletedSets;

    return Column(
      children: List.generate(exercise.targetSets, (index) {
        final isCompleted = index < completedSets.length;
        final isCurrent =
            index == completedSets.length && !_isCurrentExerciseComplete;
        final result = isCompleted ? completedSets[index] : null;
        return _buildSetRow(
          setNum: index + 1,
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          result: result,
        );
      }),
    );
  }

  Widget _buildSetRow({
    required int setNum,
    required bool isCompleted,
    required bool isCurrent,
    SetResult? result,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.accent.withValues(alpha: 0.12)
            : isCompleted
                ? AppColors.card
                : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(color: AppColors.accent.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? AppColors.success
                  : isCurrent
                      ? AppColors.accent
                      : AppColors.divider,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : Text(
                      '$setNum',
                      style: TextStyle(
                        color: isCurrent
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: isCompleted && result != null
                ? Text(
                    result.weight > 0
                        ? '${result.weight.toStringAsFixed(result.weight % 1 == 0 ? 0 : 1)} kg  ×  ${result.reps} reps'
                        : '${result.reps} reps',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : Text(
                    isCurrent ? 'Current set' : 'Set $setNum',
                    style: TextStyle(
                      color: isCurrent
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
          ),
          if (isCompleted && result != null && result.weight > 0)
            Text(
              '${(result.weight * result.reps).toStringAsFixed(0)} kg',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _NumericInputField(
                  label: 'Weight (kg)',
                  controller: _weightController,
                  allowDecimal: true,
                  hint: '0',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _NumericInputField(
                  label: 'Reps',
                  controller: _repsController,
                  allowDecimal: false,
                  hint: '0',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isResting ? null : _logSet,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.divider,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _isResting
                    ? 'Resting…'
                    : 'Log Set $_currentSetNumber of ${_currentExercise.targetSets}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCompleteActions() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Exercise complete!',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isLastExercise ? _finishWorkout : _nextExercise,
            style: FilledButton.styleFrom(
              backgroundColor:
                  _isLastExercise ? AppColors.success : AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isLastExercise
                      ? Icons.flag_rounded
                      : Icons.skip_next_rounded,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  _isLastExercise ? 'Finish Workout' : 'Next Exercise',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRestBanner() {
    final progress = _restTotalSeconds > 0
        ? _restSecondsLeft / _restTotalSeconds
        : 0.0;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.timer_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Rest  ·  ${_restSecondsLeft}s',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _adjustRest(-15),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('-15s'),
                ),
                TextButton(
                  onPressed: () => _adjustRest(15),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('+15s'),
                ),
                TextButton(
                  onPressed: _skipRest,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.divider,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.warning),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ── Numeric input helper ──────────────────────────────────────────────────

class _NumericInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool allowDecimal;
  final String hint;

  const _NumericInputField({
    required this.label,
    required this.controller,
    required this.allowDecimal,
    required this.hint,
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
        TextField(
          controller: controller,
          keyboardType: allowDecimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    );
  }
}
