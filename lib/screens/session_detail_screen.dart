import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout.dart';
import '../theme/app_theme.dart';

class SessionDetailScreen extends StatelessWidget {
  final WorkoutSession session;

  const SessionDetailScreen({super.key, required this.session});

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    if (m < 60) return '${m}m';
    final h = d.inHours;
    final rem = m - h * 60;
    return rem > 0 ? '${h}h ${rem}m' : '${h}h';
  }

  @override
  Widget build(BuildContext context) {
    final duration = session.duration;

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
          session.templateName,
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
          ...session.exercises.map(
            (e) => _buildExerciseCard(context, e),
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
            value: DateFormat('MMM d').format(session.startedAt),
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
            value: '${session.totalSetsCompleted}',
          ),
          _buildDivider(),
          _buildStat(
            context,
            label: 'Volume',
            value: '${session.totalVolume.toStringAsFixed(0)} kg',
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.divider,
    );
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
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseCard(BuildContext context, SessionExercise exercise) {
    final totalVolume = exercise.completedSets.fold(
      0.0,
      (sum, s) => sum + s.weight * s.reps,
    );

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
          if (exercise.completedSets.isEmpty)
            const Text(
              'No sets completed',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          else
            ...exercise.completedSets.map(
              (set) => Padding(
                padding: const EdgeInsets.only(top: 6),
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
                          '${set.setNumber}',
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
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
