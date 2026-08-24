import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/schedule.dart';
import '../models/workout.dart';
import '../services/schedule_service.dart';
import '../services/workout_service.dart';
import '../theme/app_theme.dart';
import 'session_detail_screen.dart';

enum _LoadState { idle, loading, loaded, error }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // Window bounds: 6 months back to 2 months forward.
  static final DateTime _firstDay =
      DateTime.now().subtract(const Duration(days: 180));
  static final DateTime _lastDay =
      DateTime.now().add(const Duration(days: 60));

  final _workoutService = WorkoutService.instance;
  final _scheduleService = ScheduleService.instance;

  _LoadState _state = _LoadState.idle;
  String _errorMessage = '';

  /// Completed sessions grouped by normalised day (year/month/day).
  Map<DateTime, List<WorkoutSession>> _sessionsByDay = {};

  /// Scheduled workouts grouped by normalised day.
  Map<DateTime, List<UpcomingWorkout>> _plannedByDay = {};

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime _normalise(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final sessions = await _workoutService.getCompletedSessions();
      final scheduled = await _scheduleService.getScheduledWorkoutsInRange(
        _firstDay,
        _lastDay,
      );

      // Group sessions by normalised day.
      final sessionsByDay = <DateTime, List<WorkoutSession>>{};
      for (final session in sessions) {
        final key = _normalise(session.startedAt);
        sessionsByDay.putIfAbsent(key, () => []).add(session);
      }

      // Group scheduled workouts by normalised day.
      final plannedByDay = <DateTime, List<UpcomingWorkout>>{};
      for (final w in scheduled) {
        final key = _normalise(w.date);
        plannedByDay.putIfAbsent(key, () => []).add(w);
      }

      setState(() {
        _sessionsByDay = sessionsByDay;
        _plannedByDay = plannedByDay;
        _state = _LoadState.loaded;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _state = _LoadState.error;
      });
    }
  }

  // ── Day-state helpers ────────────────────────────────────────────────────

  bool _isTrained(DateTime day) {
    final key = _normalise(day);
    return (_sessionsByDay[key]?.isNotEmpty) == true;
  }

  bool _isPlanned(DateTime day) {
    final key = _normalise(day);
    return (_plannedByDay[key]?.isNotEmpty) == true;
  }

  bool _isMissed(DateTime day) {
    final today = _normalise(DateTime.now());
    final normDay = _normalise(day);
    // Only past days (strictly before today) that are planned but not trained.
    return normDay.isBefore(today) && _isPlanned(day) && !_isTrained(day);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.accent,
          backgroundColor: AppColors.card,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Text(
        'Calendar',
        style: Theme.of(context).textTheme.displayMedium,
      ),
    );
  }

  Widget _buildBody() {
    return switch (_state) {
      _LoadState.idle || _LoadState.loading => _buildLoading(),
      _LoadState.error => _buildError(),
      _LoadState.loaded => _buildLoaded(),
    };
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.destructive,
          ),
          const SizedBox(height: 20),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoaded() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildLegend(),
        const SizedBox(height: 8),
        _buildCalendar(),
        const Divider(height: 1, color: AppColors.divider),
        _buildDetailsPanel(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _legendItem(AppColors.success, 'Trained'),
          const SizedBox(width: 16),
          _legendItem(AppColors.accent, 'Planned'),
          const SizedBox(width: 16),
          _legendItem(AppColors.warning, 'Missed'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
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

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: _firstDay,
      lastDay: _lastDay,
      focusedDay: _focusedDay,
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      selectedDayPredicate: (day) =>
          _selectedDay != null && isSameDay(day, _selectedDay),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = _normalise(selectedDay);
          _focusedDay = focusedDay;
        });
      },
      onPageChanged: (focusedDay) {
        setState(() => _focusedDay = focusedDay);
      },
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        leftChevronIcon: Icon(
          Icons.chevron_left_rounded,
          color: AppColors.textSecondary,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textSecondary,
        ),
        headerPadding: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: AppColors.background),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        defaultTextStyle:
            const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        weekendTextStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        outsideTextStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        disabledTextStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        todayTextStyle: const TextStyle(
          color: AppColors.onAccent,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        selectedTextStyle: const TextStyle(
          color: AppColors.onAccent,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        todayDecoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.7),
          shape: BoxShape.circle,
        ),
        markerDecoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
        tablePadding: const EdgeInsets.symmetric(horizontal: 8),
        cellMargin: const EdgeInsets.all(4),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        weekendStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          return _buildDayMarker(day);
        },
      ),
    );
  }

  Widget? _buildDayMarker(DateTime day) {
    final trained = _isTrained(day);
    final planned = _isPlanned(day);
    final missed = _isMissed(day);

    Color? dotColor;
    if (trained) {
      dotColor = AppColors.success;
    } else if (missed) {
      dotColor = AppColors.warning;
    } else if (planned) {
      dotColor = AppColors.accent;
    }

    if (dotColor == null) return null;

    return Positioned(
      bottom: 4,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
      ),
    );
  }

  // ── Details panel ────────────────────────────────────────────────────────

  Widget _buildDetailsPanel() {
    if (_selectedDay == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Text(
          'Tap a day to see details',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final sessions = _sessionsByDay[_selectedDay!] ?? [];
    final planned = _plannedByDay[_selectedDay!] ?? [];

    if (sessions.isEmpty && planned.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Text(
          'Nothing planned or logged',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMMM d').format(_selectedDay!),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (planned.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'PLANNED',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            ...planned.map(_buildPlannedRow),
          ],
          if (sessions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'COMPLETED',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            ...sessions.map(_buildSessionCard),
          ],
        ],
      ),
    );
  }

  Widget _buildPlannedRow(UpcomingWorkout w) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              w.entry.templateName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (w.isMoved)
            const Text(
              'Moved',
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    if (m < 60) return '${m}m';
    final h = d.inHours;
    final rem = m - h * 60;
    return rem > 0 ? '${h}h ${rem}m' : '${h}h';
  }

  Widget _buildSessionCard(WorkoutSession session) {
    final duration = session.duration;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionDetailScreen(session: session),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: AppColors.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.templateName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a').format(session.startedAt),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (duration != null)
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${session.totalSetsCompleted} sets',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
