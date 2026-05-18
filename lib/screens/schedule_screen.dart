import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';
import '../models/workout.dart';
import '../services/schedule_service.dart';
import '../services/workout_service.dart';
import '../theme/app_theme.dart';
import 'active_workout_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _scheduleService = ScheduleService.instance;
  final _workoutService = WorkoutService.instance;

  List<UpcomingWorkout> _upcoming = [];
  List<ScheduleEntry> _entries = [];
  DateTime? _anchorMonday;
  int? _currentCycleSlot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _scheduleService.getUpcomingWorkouts(days: 28),
      _scheduleService.getScheduleEntries(),
      _scheduleService.getScheduleAnchorMonday(),
    ]);
    final entries = results[1] as List<ScheduleEntry>;
    final anchor = results[2] as DateTime;

    int? slot;
    if (entries.any((e) => e.cycleLength == 2)) {
      slot = await _scheduleService.getCurrentCycleSlotForToday(2);
    }

    if (mounted) {
      setState(() {
        _upcoming = results[0] as List<UpcomingWorkout>;
        _entries = entries;
        _anchorMonday = anchor;
        _currentCycleSlot = slot;
        _loading = false;
      });
    }
  }

  Future<void> _showAddEntrySheet() async {
    final templates = await _workoutService.getWorkoutTemplates();
    if (!mounted) return;
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a workout template first'),
          backgroundColor: AppColors.card,
        ),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddEntrySheet(
        templates: templates,
        onAdd: (entries) async {
          for (final e in entries) {
            await _scheduleService.addScheduleEntry(
              templateId: e.templateId,
              templateName: e.templateName,
              dayOfWeek: e.dayOfWeek,
              cycleLength: e.cycleLength,
              cycleIndex: e.cycleIndex,
            );
          }
          if (ctx.mounted) Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  Future<void> _startWorkout(UpcomingWorkout upcoming) async {
    final template =
        await _workoutService.getWorkoutTemplate(upcoming.entry.templateId);
    if (!mounted) return;
    if (template == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workout template no longer exists'),
          backgroundColor: AppColors.card,
        ),
      );
      return;
    }
    if (template.exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add exercises to this workout first'),
          backgroundColor: AppColors.card,
        ),
      );
      return;
    }

    final activeSession = await _workoutService.getActiveSession();
    if (!mounted) return;
    if (activeSession != null) {
      final abandon = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text(
            'Active Workout',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'You have an active "${activeSession.templateName}" workout. Abandon it?',
            style: const TextStyle(color: AppColors.textSecondary),
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
                backgroundColor: Colors.red.shade700,
              ),
              child: const Text('Abandon & Start'),
            ),
          ],
        ),
      );
      if (abandon != true) return;
      await _workoutService.abandonSession(activeSession.id);
    }

    if (!mounted) return;
    final session = await _workoutService.startWorkoutSession(template);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutScreen(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.accent,
                      backgroundColor: AppColors.card,
                      child: _entries.isEmpty
                          ? _buildEmptyState()
                          : _buildContent(),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_schedule',
        onPressed: _showAddEntrySheet,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Schedule',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ),
              if (_entries.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.format_list_bulleted_rounded),
                  color: AppColors.textSecondary,
                  tooltip: 'Your schedule',
                  padding: EdgeInsets.zero,
                  onPressed: _showScheduleSheet,
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 72,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 24),
              Text(
                'No schedule yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Add workouts with an A/B alternating pattern or a simple weekly repeat.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _showAddEntrySheet,
                icon: const Icon(Icons.add),
                label: const Text('Add Scheduled Workout'),
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
      ],
    );
  }

  Widget _buildContent() {
    if (_upcoming.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'No upcoming workouts in the next 4 weeks.\nTap the list icon to review your schedule.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [_buildUpcomingSection()],
    );
  }

  Widget _buildUpcomingSection() {
    final grouped = <String, List<UpcomingWorkout>>{};
    final weekLabels = <String, String>{};

    for (final w in _upcoming) {
      final weekKey = _weekKey(w.date);
      grouped.putIfAbsent(weekKey, () => []).add(w);
      weekLabels[weekKey] = _weekLabel(w.date);
    }

    final weeks = grouped.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UPCOMING',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        ...weeks.map(
          (weekKey) => _buildWeekGroup(
            label: weekLabels[weekKey]!,
            workouts: grouped[weekKey]!,
          ),
        ),
      ],
    );
  }

  String _weekKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return DateFormat('yyyy-MM-dd').format(monday);
  }

  String _weekLabel(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final now = DateTime.now();
    final thisMonday = now.subtract(Duration(days: now.weekday - 1));
    final nextMonday = thisMonday.add(const Duration(days: 7));

    String base;
    if (_isSameDay(monday, thisMonday)) {
      base = 'This week';
    } else if (_isSameDay(monday, nextMonday)) {
      base = 'Next week';
    } else {
      final start = DateFormat('MMM d').format(monday);
      final end = DateFormat('MMM d').format(sunday);
      base = '$start – $end';
    }

    // Append Week A/B indicator when 2-week cycle entries exist
    final has2Week = _entries.any((e) => e.cycleLength == 2);
    if (has2Week && _anchorMonday != null) {
      final slot = _scheduleService.cycleSlotForDate(date, _anchorMonday!, 2);
      base = '$base · ${slot == 0 ? 'Week A' : 'Week B'}';
    }

    return base;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildWeekGroup({
    required String label,
    required List<UpcomingWorkout> workouts,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...workouts.map((w) => _buildUpcomingRow(w)),
        ],
      ),
    );
  }

  Widget _buildUpcomingRow(UpcomingWorkout w) {
    final isToday = w.isToday;
    return InkWell(
      onTap: () => _showExceptionSheet(w),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEE').format(w.date).toUpperCase(),
                    style: TextStyle(
                      color: isToday ? AppColors.accent : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    DateFormat('d').format(w.date),
                    style: TextStyle(
                      color: isToday ? AppColors.accent : AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.entry.templateName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (w.isMoved) ...[
                    const SizedBox(height: 2),
                    const Text(
                      'Moved',
                      style: TextStyle(color: AppColors.warning, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (isToday)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.divider,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExceptionSheet(UpcomingWorkout w) async {
    final isToday = w.isToday;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 36,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    w.entry.templateName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            Text(
              DateFormat('EEEE, MMMM d').format(w.date),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            if (w.isMoved)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Moved from ${DateFormat('EEEE, MMMM d').format(w.originalDate!)}',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            if (isToday) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _startWorkout(w);
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Workout'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (w.isMoved) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _scheduleService.removeException(
                      entryId: w.entry.id,
                      originalDate: w.originalDate!,
                    );
                    _load();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.divider),
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Cancel Move'),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _showMoveDate(w);
                  },
                  icon: const Icon(Icons.edit_calendar_rounded),
                  label: const Text('Move to another day'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.divider),
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _scheduleService.addSkipException(
                      entryId: w.entry.id,
                      originalDate: w.date,
                    );
                    _load();
                  },
                  icon: const Icon(
                    Icons.remove_circle_outline_rounded,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Skip this workout',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showMoveDate(UpcomingWorkout w) async {
    final now = DateTime.now();
    final initial = w.date.isAfter(now) ? w.date : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            surface: AppColors.card,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    await _scheduleService.addMoveException(
      entryId: w.entry.id,
      originalDate: w.date,
      newDate: DateTime(picked.year, picked.month, picked.day),
    );
    _load();
  }

  Future<void> _showScheduleSheet() async {
    var sheetEntries = List<ScheduleEntry>.from(_entries);
    bool anyChanged = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheetState) {
          // ── edit sheet ───────────────────────────────────────────────────
          Future<void> openEdit(ScheduleEntry entry) async {
            int selectedDay = entry.dayOfWeek;

            const days = [
              (DateTime.monday, 'Mon'),
              (DateTime.tuesday, 'Tue'),
              (DateTime.wednesday, 'Wed'),
              (DateTime.thursday, 'Thu'),
              (DateTime.friday, 'Fri'),
              (DateTime.saturday, 'Sat'),
              (DateTime.sunday, 'Sun'),
            ];

            final result = await showModalBottomSheet<({bool delete, int newDay})>(
              context: ctx,
              backgroundColor: AppColors.surface,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (editCtx) => StatefulBuilder(
                builder: (_, setEditState) => Padding(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: MediaQuery.of(editCtx).viewInsets.bottom + 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.templateName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(editCtx),
                            icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      Text(
                        entry.repeatLabel,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Move to day',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: days.map((day) {
                          final (value, label) = day;
                          final isSelected = selectedDay == value;
                          return GestureDetector(
                            onTap: () => setEditState(() => selectedDay = value),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accent : AppColors.card,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: selectedDay != entry.dayOfWeek
                              ? () => Navigator.pop(
                                    editCtx,
                                    (delete: false, newDay: selectedDay),
                                  )
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(
                            editCtx,
                            (delete: true, newDay: 0),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Delete entry',
                            style: TextStyle(color: Colors.red, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            if (result == null) return;
            if (result.delete) {
              await _scheduleService.removeScheduleEntry(entry.id);
              setSheetState(() => sheetEntries.remove(entry));
            } else {
              await _scheduleService.updateScheduleEntryDay(entry.id, result.newDay);
              setSheetState(() {
                final idx = sheetEntries.indexOf(entry);
                if (idx != -1) {
                  sheetEntries[idx] = ScheduleEntry(
                    id: entry.id,
                    templateId: entry.templateId,
                    templateName: entry.templateName,
                    dayOfWeek: result.newDay,
                    cycleLength: entry.cycleLength,
                    cycleIndex: entry.cycleIndex,
                  );
                }
              });
            }
            anyChanged = true;
          }

          // ── row / group builders ─────────────────────────────────────────
          Widget buildRow(ScheduleEntry entry) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openEdit(entry),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        entry.dayName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.templateName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.divider,
                      size: 18,
                    ),
                  ],
                ),
              ),
            );
          }

          Widget buildGroup(String title, List<ScheduleEntry> entries, Color color, bool isCurrent) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'current',
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  ...entries.map(buildRow),
                ],
              ),
            );
          }

          // ── layout ───────────────────────────────────────────────────────
          final currentSlot = _currentCycleSlot;

          final everyWeek = sheetEntries.where((e) => e.cycleLength <= 1).toList()
            ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
          final weekA = sheetEntries.where((e) => e.cycleLength == 2 && e.cycleIndex == 0).toList()
            ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
          final weekB = sheetEntries.where((e) => e.cycleLength == 2 && e.cycleIndex == 1).toList()
            ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
          final customGroups = <String, List<ScheduleEntry>>{};
          for (final e in sheetEntries.where((e) => e.cycleLength > 2)) {
            customGroups.putIfAbsent(e.repeatLabel, () => []).add(e);
          }
          final customKeys = customGroups.keys.toList()..sort();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your Schedule',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: sheetEntries.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                          'No scheduled workouts.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                        children: [
                          if (everyWeek.isNotEmpty) ...[
                            buildGroup('EVERY WEEK', everyWeek, AppColors.accentSecondary, false),
                            const SizedBox(height: 10),
                          ],
                          if (weekA.isNotEmpty) ...[
                            buildGroup('WEEK A', weekA, AppColors.accent, currentSlot == 0),
                            const SizedBox(height: 10),
                          ],
                          if (weekB.isNotEmpty) ...[
                            buildGroup('WEEK B', weekB, AppColors.warning, currentSlot == 1),
                            const SizedBox(height: 10),
                          ],
                          ...customKeys.map(
                            (k) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: buildGroup(k.toUpperCase(), customGroups[k]!, AppColors.accent, false),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );

    if (anyChanged) _load();
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────

class _EntrySpec {
  final String templateId;
  final String templateName;
  final int dayOfWeek;
  final int cycleLength;
  final int cycleIndex;

  const _EntrySpec({
    required this.templateId,
    required this.templateName,
    required this.dayOfWeek,
    required this.cycleLength,
    required this.cycleIndex,
  });
}

typedef _OnAddCallback = Future<void> Function(List<_EntrySpec> entries);

// ── Add Entry Bottom Sheet ────────────────────────────────────────────────────

enum _AddMode { everyWeek, alternating, custom }

class _AddEntrySheet extends StatefulWidget {
  final List<WorkoutTemplate> templates;
  final _OnAddCallback onAdd;

  const _AddEntrySheet({required this.templates, required this.onAdd});

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  _AddMode _mode = _AddMode.everyWeek;
  final Set<int> _selectedDays = {};

  WorkoutTemplate? _selectedTemplate; // custom mode only
  final Map<int, WorkoutTemplate?> _everyWeekTemplates = {}; // everyWeek, keyed by dayOfWeek
  final Map<int, WorkoutTemplate?> _weekATemplates = {}; // alternating, keyed by dayOfWeek
  final Map<int, WorkoutTemplate?> _weekBTemplates = {}; // alternating, keyed by dayOfWeek

  int _cycleLength = 2;
  int _cycleIndex = 0;

  static const _days = [
    (DateTime.monday, 'Mon'),
    (DateTime.tuesday, 'Tue'),
    (DateTime.wednesday, 'Wed'),
    (DateTime.thursday, 'Thu'),
    (DateTime.friday, 'Fri'),
    (DateTime.saturday, 'Sat'),
    (DateTime.sunday, 'Sun'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.templates.isNotEmpty) {
      _selectedTemplate = widget.templates.first;
    }
  }

  bool get _canSave {
    if (_selectedDays.isEmpty) return false;
    if (_mode == _AddMode.everyWeek) {
      return _selectedDays.every((d) => _everyWeekTemplates[d] != null);
    }
    if (_mode == _AddMode.alternating) {
      return _selectedDays.every(
        (d) => _weekATemplates[d] != null && _weekBTemplates[d] != null,
      );
    }
    return _selectedTemplate != null;
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Schedule a Workout',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildModeSelector(),
            const SizedBox(height: 24),
            const Text(
              'Days',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            _buildDayPicker(),
            const SizedBox(height: 20),
            if (_mode == _AddMode.everyWeek) _buildEveryWeekContent(),
            if (_mode == _AddMode.alternating) _buildAlternatingContent(),
            if (_mode == _AddMode.custom) _buildCustomContent(),
            const SizedBox(height: 24),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(
          child: _ModeChip(
            label: 'Every week',
            icon: Icons.repeat_rounded,
            selected: _mode == _AddMode.everyWeek,
            color: AppColors.accentSecondary,
            onTap: () => setState(() => _mode = _AddMode.everyWeek),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChip(
            label: 'A/B',
            icon: Icons.swap_horiz_rounded,
            selected: _mode == _AddMode.alternating,
            color: AppColors.accent,
            onTap: () => setState(() => _mode = _AddMode.alternating),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChip(
            label: 'Custom',
            icon: Icons.loop_rounded,
            selected: _mode == _AddMode.custom,
            color: AppColors.textSecondary,
            onTap: () => setState(() => _mode = _AddMode.custom),
          ),
        ),
      ],
    );
  }

  Widget _buildDayPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _days.map((day) {
        final (value, label) = day;
        final isSelected = _selectedDays.contains(value);
        return GestureDetector(
          onTap: () => setState(() {
            if (isSelected) {
              _selectedDays.remove(value);
              _everyWeekTemplates.remove(value);
              _weekATemplates.remove(value);
              _weekBTemplates.remove(value);
            } else {
              _selectedDays.add(value);
              final first = widget.templates.isNotEmpty ? widget.templates.first : null;
              _everyWeekTemplates[value] = first;
              _weekATemplates[value] = first;
              _weekBTemplates[value] = first;
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent : AppColors.card,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEveryWeekContent() {
    if (_selectedDays.isEmpty) {
      return const Text(
        'Select one or more days above.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
    }

    final sortedDays = _selectedDays.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Workout per day',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        ...sortedDays.map(
          (day) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    _dayAbbrev(day),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTemplatePicker(
                    _everyWeekTemplates[day],
                    (t) => setState(() => _everyWeekTemplates[day] = t),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlternatingContent() {
    if (_selectedDays.isEmpty) {
      return const Text(
        'Select one or more days above.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
    }

    final sortedDays = _selectedDays.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column headers
        Row(
          children: [
            const SizedBox(width: 44),
            Expanded(
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
                  const SizedBox(width: 5),
                  const Text(
                    'Week A',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Week B',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...sortedDays.map((day) => _buildAlternatingDayRow(day)),
        const SizedBox(height: 4),
        Text(
          'Each day gets two slots — one for Week A, one for Week B.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAlternatingDayRow(int day) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _dayAbbrev(day),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactDropdown(
              value: _weekATemplates[day],
              borderColor: AppColors.accent,
              onChanged: (t) => setState(() => _weekATemplates[day] = t),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactDropdown(
              value: _weekBTemplates[day],
              borderColor: AppColors.warning,
              onChanged: (t) => setState(() => _weekBTemplates[day] = t),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDropdown({
    required WorkoutTemplate? value,
    required Color borderColor,
    required ValueChanged<WorkoutTemplate?> onChanged,
  }) {
    return DropdownButtonFormField<WorkoutTemplate>(
      value: value,
      dropdownColor: AppColors.card,
      isExpanded: true,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor.withValues(alpha: 0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: widget.templates
          .map(
            (t) => DropdownMenuItem(
              value: t,
              child: Text(
                t.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildCustomContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedDays.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Select one or more days above.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        const Text(
          'Workout',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        _buildTemplatePicker(
          _selectedTemplate,
          (t) => setState(() => _selectedTemplate = t),
        ),
        const SizedBox(height: 16),
        const Text(
          'Cycle length (weeks)',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _cycleLength,
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
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: List.generate(7, (i) => i + 2)
              .map((n) => DropdownMenuItem(value: n, child: Text('$n weeks')))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _cycleLength = v;
              if (_cycleIndex >= _cycleLength) _cycleIndex = _cycleLength - 1;
            });
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Active on which week',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_cycleLength, (i) {
            final selected = _cycleIndex == i;
            return ChoiceChip(
              label: Text('Week ${i + 1}'),
              selected: selected,
              onSelected: (_) => setState(() => _cycleIndex = i),
              selectedColor: AppColors.accent.withValues(alpha: 0.25),
              labelStyle: TextStyle(
                color: selected ? AppColors.accent : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: selected ? AppColors.accent : AppColors.divider,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _canSave ? _onSave : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Add to Schedule',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  void _onSave() {
    final entries = <_EntrySpec>[];

    if (_mode == _AddMode.everyWeek) {
      for (final day in _selectedDays) {
        final t = _everyWeekTemplates[day]!;
        entries.add(_EntrySpec(
          templateId: t.id,
          templateName: t.name,
          dayOfWeek: day,
          cycleLength: 1,
          cycleIndex: 0,
        ));
      }
    } else if (_mode == _AddMode.alternating) {
      for (final day in _selectedDays) {
        entries.add(_EntrySpec(
          templateId: _weekATemplates[day]!.id,
          templateName: _weekATemplates[day]!.name,
          dayOfWeek: day,
          cycleLength: 2,
          cycleIndex: 0,
        ));
        entries.add(_EntrySpec(
          templateId: _weekBTemplates[day]!.id,
          templateName: _weekBTemplates[day]!.name,
          dayOfWeek: day,
          cycleLength: 2,
          cycleIndex: 1,
        ));
      }
    } else {
      for (final day in _selectedDays) {
        entries.add(_EntrySpec(
          templateId: _selectedTemplate!.id,
          templateName: _selectedTemplate!.name,
          dayOfWeek: day,
          cycleLength: _cycleLength,
          cycleIndex: _cycleIndex,
        ));
      }
    }

    widget.onAdd(entries);
  }

  Widget _buildTemplatePicker(
    WorkoutTemplate? value,
    ValueChanged<WorkoutTemplate?> onChanged,
  ) {
    return DropdownButtonFormField<WorkoutTemplate>(
      value: value,
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
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: widget.templates
          .map(
            (t) => DropdownMenuItem(
              value: t,
              child: Text(t.name),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  String _dayAbbrev(int weekday) {
    const abbrevs = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return abbrevs[weekday];
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : AppColors.divider,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? color : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? color : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
