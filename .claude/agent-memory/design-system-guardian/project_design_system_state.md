---
name: project-design-system-state
description: Full inventory of AppColors constants, established design patterns, and known violations in this Flutter fitness app as of the initial comprehensive audit (2026-06-06).
metadata:
  type: project
---

Design rules document created at: `/Users/nyanev/projects/personal/fitness-app/lib/theme/DESIGN_RULES.md`

**Why:** First comprehensive audit of all widgets and screens revealed multiple inline color violations, duplicated form widgets, and missing AppColors constants.

**How to apply:** On every future review, open DESIGN_RULES.md first as the authoritative source. Update it whenever a new rule is authored.

## AppColors constants (as of audit)
background, surface, card, accent, accentSecondary, textPrimary, textSecondary, divider,
weightColor, fatColor, success, warning, heartRateColor, sleepColor, workoutColor.

## Missing constants to be added (Rule 1.2)
- `destructive` (~#FF3B30) — replaces Colors.red / Colors.red.shade700 / Colors.red.shade900 / Colors.redAccent
- `onAccent` (#FFFFFF) — replaces Colors.white on accent-colored buttons
- `deltaPositiveColor` (~#FF3B30) — for delta badges (increase = bad)
- `deltaNegativeColor` (~#32D74B) — for delta badges (decrease = good)
- `muscleChest/Back/Legs/Shoulders/Biceps/Triceps/Core/Cardio` — 8 inline colors in AddExerciseScreen

## Known inline color violations (all violate Rule 1.1)

### lib/theme/app_theme.dart (lines 31–35)
- `BottomNavigationBarThemeData` uses Color(0xFF1A1A1A) and Color(0xFF6C63FF) instead of AppColors.surface and AppColors.accent.

### lib/widgets/body_composition_overview_chart.dart (lines 7–9)
- Three module-level constants `_chartWeightBlue`, `_chartFatRed`, `_chartMuscleGreen` are inline Color(0x...) literals. Must become AppColors constants.

### lib/widgets/history_tile.dart (lines 115–117)
- `_DeltaBadge.color` uses `Colors.redAccent` / `Colors.greenAccent`.
- Dead conditional: both branches of `unit == '%'` produce identical colors.
- Must use `AppColors.deltaPositiveColor` / `AppColors.deltaNegativeColor`.

### lib/screens/home_screen.dart (line 174, 369)
- FilledButton foregroundColor: `Colors.white` → `AppColors.onAccent`
- Error icon color: `Colors.redAccent` → `AppColors.destructive`

### lib/screens/dashboard_screen.dart (lines 154, 285, 349)
- `Colors.white` on import button
- Error icon: `Colors.redAccent`
- `Colors.red.shade700` on Abandon FilledButton

### lib/screens/active_workout_screen.dart (lines 99, 240, 484–487)
- SnackBar `backgroundColor: Colors.red`
- `Colors.red.shade700` on abandon FilledButton
- Set row: `Colors.white` on set number icon in circle

### lib/screens/workouts_screen.dart (lines 138, 186, 293, 298, 323, 375)
- `Colors.white` on FAB icon
- `Colors.red.shade700` on abandon/delete dialogs
- `Colors.red.shade900` on Dismissible delete background
- `Colors.white` on Dismissible delete icon

### lib/screens/schedule_screen.dart (lines 147, 198, 629, 768)
- `Colors.white` on FAB icon
- `Colors.red.shade700` on abandon dialog
- `Colors.white` on day-selector selected text
- `Colors.red` on "Skip this workout" text/icon
- `Colors.red` (line 817) on "Delete entry" TextButton

### lib/screens/workout_detail_screen.dart (lines 370, 374)
- `Colors.red.shade900` on Dismissible background
- `Colors.white` on Dismissible icon

### lib/screens/health_metric_detail_screen.dart (line 109)
- `Colors.redAccent` / `Colors.greenAccent` in `_DeltaBadge`

### lib/screens/add_exercise_screen.dart (lines 224, 226, 369–385)
- `Colors.white` on FloatingActionButton foregroundColor
- Eight inline `Color(0x...)` in `_colorForMuscleGroup()`

### lib/screens/health_screen.dart (line 207)
- Error icon: `Colors.redAccent`

## Known code-duplication violations

### _StepperField / _WeightField / _RestTimeSelector
Defined identically in both `workout_detail_screen.dart` and `add_exercise_screen.dart`.
Must be extracted to `lib/widgets/workout_form_fields.dart`.

### _DeltaBadge
Defined in `history_tile.dart` AND `health_metric_detail_screen.dart`. Must be unified
into a single shared widget (e.g. `lib/widgets/delta_badge.dart`).

### _get7DayChange / _groupSleepByNight
Private helpers duplicated in `dashboard_screen.dart` (and `home_screen.dart`/`health_screen.dart`).
Must be extracted to `lib/utils/health_display_utils.dart`.

## Section header caps style duplication
`titleMedium.copyWith(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700)`
used in dashboard_screen.dart and schedule_screen.dart. Must be centralised in AppTheme.
