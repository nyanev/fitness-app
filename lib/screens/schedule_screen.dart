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
    if (mounted) {
      setState(() {
        _upcoming = results[0] as List<UpcomingWorkout>;
        _entries = results[1] as List<ScheduleEntry>;
        _anchorMonday = results[2] as DateTime;
        _loading = false;
      });
    }
  }

  Future<void> _shiftScheduleOneWeek() async {
    await _scheduleService.shiftScheduleForwardOneWeek();
    _load();
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
        onAdd:
            (templateId, templateName, dayOfWeek, cycleLength, cycleIndex) async {
          await _scheduleService.addScheduleEntry(
            templateId: templateId,
            templateName: templateName,
            dayOfWeek: dayOfWeek,
            cycleLength: cycleLength,
            cycleIndex: cycleIndex,
          );
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
    final anchor = _anchorMonday;
    final anchorText = anchor != null
        ? DateFormat('EEE, MMM d').format(anchor)
        : '—';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rotation starts',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      anchorText,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _shiftScheduleOneWeek,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.rotate_right_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Shift +1 wk',
                        style: TextStyle(
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
          const SizedBox(height: 10),
          Text(
            'Each workout can repeat every week or on one week of a 2–8 week rotation. '
            'Use Shift when your real calendar slips vs the plan.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
                'Pick days, workouts, and whether they repeat weekly or on a longer rotation (e.g. Mon/Fri one week, Wed the next).',
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        if (_upcoming.isNotEmpty) ...[
          _buildUpcomingSection(),
          const SizedBox(height: 28),
        ],
        _buildAllEntriesSection(),
      ],
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

    if (_isSameDay(monday, thisMonday)) {
      return 'This week';
    }
    if (_isSameDay(monday, nextMonday)) {
      return 'Next week';
    }
    final start = DateFormat('MMM d').format(monday);
    final end = DateFormat('MMM d').format(sunday);
    return '$start – $end';
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
      onTap: isToday ? () => _startWorkout(w) : null,
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
                  const SizedBox(height: 2),
                  Text(
                    w.entry.repeatLabel,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isToday)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Start',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

  Widget _buildAllEntriesSection() {
    final groups = <String, List<ScheduleEntry>>{};
    for (final e in _entries) {
      groups.putIfAbsent(e.repeatLabel, () => []).add(e);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == 'Every week') return -1;
        if (b == 'Every week') return 1;
        return a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR SCHEDULE',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        ...keys.map((k) {
          final color = _colorForRepeatLabel(k);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildEntryGroup(k, groups[k]!, color),
          );
        }),
        if (_entries.isEmpty)
          const Center(
            child: Text(
              'No scheduled workouts',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  Color _colorForRepeatLabel(String label) {
    if (label == 'Every week') return AppColors.accentSecondary;
    final idx = label.hashCode.abs() % 2;
    return idx == 0 ? AppColors.accent : AppColors.warning;
  }

  Widget _buildEntryGroup(
    String title,
    List<ScheduleEntry> entries,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
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
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...entries.map((e) => _buildEntryRow(e)),
        ],
      ),
    );
  }

  Widget _buildEntryRow(ScheduleEntry entry) {
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: const BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) async {
        await _scheduleService.removeScheduleEntry(entry.id);
        _load();
      },
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
              Icons.drag_handle_rounded,
              color: AppColors.divider,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Entry Bottom Sheet ───────────────────────────────────────────────────

typedef _OnAddCallback = void Function(
  String templateId,
  String templateName,
  int dayOfWeek,
  int cycleLength,
  int cycleIndex,
);

class _AddEntrySheet extends StatefulWidget {
  final List<WorkoutTemplate> templates;
  final _OnAddCallback onAdd;

  const _AddEntrySheet({required this.templates, required this.onAdd});

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  int _selectedDay = DateTime.monday;
  WorkoutTemplate? _selectedTemplate;

  /// `true` = every calendar week; `false` = use [_cycleLength] / [_cycleIndex].
  bool _weekly = true;
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
    _selectedTemplate = widget.templates.first;
  }

  void _onCycleLengthChanged(int? v) {
    if (v == null) return;
    setState(() {
      _cycleLength = v;
      if (_cycleIndex >= _cycleLength) {
        _cycleIndex = _cycleLength - 1;
      }
    });
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
            const SizedBox(height: 24),
            const Text(
              'Day',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            _buildDayPicker(),
            const SizedBox(height: 20),
            const Text(
              'Workout',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _buildTemplatePicker(),
            const SizedBox(height: 20),
            const Text(
              'Repeats',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _RepeatChip(
                    label: 'Every week',
                    icon: Icons.repeat_rounded,
                    selected: _weekly,
                    color: AppColors.accentSecondary,
                    onTap: () => setState(() => _weekly = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RepeatChip(
                    label: 'Rotating',
                    icon: Icons.loop_rounded,
                    selected: !_weekly,
                    color: AppColors.accent,
                    onTap: () => setState(() => _weekly = false),
                  ),
                ),
              ],
            ),
            if (!_weekly) ...[
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
                items: List.generate(
                  7,
                  (i) => i + 2,
                ).map((n) => DropdownMenuItem(value: n, child: Text('$n weeks'))).toList(),
                onChanged: _onCycleLengthChanged,
              ),
              const SizedBox(height: 16),
              const Text(
                'Active on which week of the cycle',
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
              const SizedBox(height: 8),
              Text(
                'Example: Mon/Fri on weeks 1 & 2 of a 2-week cycle, Wed on week 1 of a 2-week cycle — '
                'add three rows with Rotating and pick the right week slot.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedTemplate != null
                    ? () {
                        final len = _weekly ? 1 : _cycleLength;
                        final idx = _weekly ? 0 : _cycleIndex;
                        widget.onAdd(
                          _selectedTemplate!.id,
                          _selectedTemplate!.name,
                          _selectedDay,
                          len,
                          idx,
                        );
                      }
                    : null,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _days.map((day) {
        final (value, label) = day;
        final isSelected = _selectedDay == value;
        return GestureDetector(
          onTap: () => setState(() => _selectedDay = value),
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

  Widget _buildTemplatePicker() {
    return DropdownButtonFormField<WorkoutTemplate>(
      value: _selectedTemplate,
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
      onChanged: (t) => setState(() => _selectedTemplate = t),
    );
  }
}

class _RepeatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _RepeatChip({
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
            Icon(icon, color: selected ? color : AppColors.textSecondary, size: 22),
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
