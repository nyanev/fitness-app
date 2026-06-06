# Design Rules — Fitness App

This document is the authoritative record of UI/UX design rules for this Flutter fitness app.
All widgets in `lib/widgets/` and screens in `lib/screens/` must comply. Rules are numbered
for easy citation in code reviews.

---

## 1. Color System

### Rule 1.1 — No Inline Colors
Every color value in a widget or screen MUST reference an `AppColors` constant.
`Color(0x...)` literals and `Colors.*` Material constants (e.g. `Colors.white`,
`Colors.redAccent`, `Colors.greenAccent`, `Colors.red.shade700`, `Colors.red.shade900`,
`Colors.white`) are **prohibited** in `lib/widgets/` and `lib/screens/`.
The only permitted site for raw `Color(0x...)` literals is `lib/theme/app_theme.dart`.

**Required fix pattern**: replace every inline color with a named `AppColors` constant.
If no suitable constant exists, add one to `AppColors` with a descriptive semantic name.

### Rule 1.2 — Semantic Color Constants Required
`AppColors` must cover every semantic use case encountered in the product.
Currently established constants and their intended use:

| Constant | Hex | Use |
|---|---|---|
| `background` | `#0D0D0D` | Scaffold / screen background |
| `surface` | `#1A1A1A` | Bottom sheets, app bars, overlay surfaces |
| `card` | `#242424` | Cards, list containers, input fill |
| `accent` | `#6C63FF` | Primary CTA, selected states, tint |
| `accentSecondary` | `#00D9A6` | Secondary accent (e.g. "every week" schedule group) |
| `textPrimary` | `#FFFFFF` | Primary body and headline text |
| `textSecondary` | `#9E9E9E` | Labels, subtitles, placeholders |
| `divider` | `#2C2C2C` | List separators, thin rule lines |
| `weightColor` | `#6C63FF` | Weight metric accent (same as `accent`) |
| `fatColor` | `#00D9A6` | Body-fat metric accent (same as `accentSecondary`) |
| `success` | `#34C759` | Completed/positive state |
| `warning` | `#FF9F0A` | Moved/caution state, rest timer progress |
| `heartRateColor` | `#FF453A` | Heart-rate metric accent |
| `sleepColor` | `#5E5CE6` | Sleep metric accent |
| `workoutColor` | `#34C759` | Workout activity accent (same as `success`) |
| `destructive` | `#FF3B30` | Delete/danger actions, abandon, error icons, skip |
| `onAccent` | `#FFFFFF` | Foreground on accent-colored buttons/badges |
| `deltaPositiveColor` | `#FF3B30` | Delta badge increase (weight/fat up = bad) |
| `deltaNegativeColor` | `#32D74B` | Delta badge decrease (down = good) |
| `chartWeight` | `#448AFF` | Body-comp overview chart: weight series |
| `chartFat` | `#FF5252` | Body-comp overview chart: body-fat series |
| `chartMuscle` | `#69F0AE` | Body-comp overview chart: muscle series |
| `muscleChest` | `#FF6B6B` | Exercise muscle-group: chest |
| `muscleBack` | `#4ECDC4` | Exercise muscle-group: back |
| `muscleLegs` | `#45B7D1` | Exercise muscle-group: legs |
| `muscleShoulders` | `#FFD93D` | Exercise muscle-group: shoulders |
| `muscleBiceps` | `#A78BFA` | Exercise muscle-group: biceps |
| `muscleTriceps` | `#6EE7B7` | Exercise muscle-group: triceps |
| `muscleCore` | `#FB923C` | Exercise muscle-group: core |
| `muscleCardio` | `#F472B6` | Exercise muscle-group: cardio |

### Rule 1.3 — Theme Colors in ThemeData
`AppTheme.dark.bottomNavigationBarTheme` must reference `AppColors.surface`,
`AppColors.accent`, and `AppColors.textSecondary` rather than inline `Color(0x...)`
literals. (Resolved.)

---

## 2. Typography

### Rule 2.1 — Use Theme Text Styles
All text must derive from `Theme.of(context).textTheme.*` or from `AppColors` constants
applied via `.copyWith()`. Hard-coded `fontSize`, `fontWeight`, `color`, and
`letterSpacing` values that do not correspond to a named text theme style are a violation
unless they represent an intentional, documented deviation from the scale.

### Rule 2.2 — Established Text Style Usage
| Style | fontSize | weight | color | Typical use |
|---|---|---|---|---|
| `displayLarge` | 48 | w700 | textPrimary | Reserved (not used in current screens) |
| `displayMedium` | 34 | w700 | textPrimary | Screen-level hero headings |
| `titleLarge` | 20 | w600 | textPrimary | Section headings, sheet titles |
| `titleMedium` | 14 | w500 | textSecondary | Caps/section labels |
| `bodyMedium` | 14 | normal | textSecondary | Descriptive body copy |
| `bodySmall` | 12 | normal | textSecondary | Timestamps, supplementary info |

Ad-hoc section labels using `titleMedium.copyWith(fontSize: 11, letterSpacing: 1.4,
fontWeight: FontWeight.w700)` appear in both `DashboardScreen` and `ScheduleScreen`
(Rule 2.3 below).

### Rule 2.3 — Section Header Label Style (NEW RULE)
Caps-style section header labels (e.g. "UPCOMING TRAINING", "UPCOMING") must use a
consistent text style across all screens. The standard is:

```dart
Theme.of(context).textTheme.titleMedium?.copyWith(
  fontSize: 11,
  letterSpacing: 1.4,
  fontWeight: FontWeight.w700,
)
```

It is defined centrally as `TextTheme.labelSmall` in `AppTheme.dark` and referenced via
`Theme.of(context).textTheme.labelSmall` from both `DashboardScreen._buildUpcomingSection()`
and `ScheduleScreen._buildUpcomingSection()`. (Resolved.) New caps section headers must use
`labelSmall` — do not re-inline the `copyWith` form.

---

## 3. Spacing and Layout

### Rule 3.1 — Standard Spacing Scale
Spacing values in use across the app. New screens must use values from this scale rather
than arbitrary one-off numbers.

| Scale token | Value | Common use |
|---|---|---|
| `xs` | 4 px | Icon-to-text gaps, tight internal padding |
| `sm` | 8 px | Inter-element gaps inside components |
| `md` | 12 px | Inter-card gaps, list separators |
| `lg` | 16 px | Section padding, input padding |
| `xl` | 20 px | Screen horizontal margin, card padding |
| `xxl` | 24 px | Major section separators, sheet top padding |
| `hero` | 28–32 px | Pre-section spacing in scrolling screens |

### Rule 3.2 — Screen Horizontal Margin
Screens use a consistent horizontal margin of **20 px** for all top-level content
(`EdgeInsets.symmetric(horizontal: 20)`). This is established by `Padding` wrappers
around headers and section widgets. Do not deviate.

### Rule 3.3 — Sheet Internal Padding
All modal bottom sheets use `EdgeInsets.only(left: 24, right: 24, top: 24,
bottom: MediaQuery.of(ctx).viewInsets.bottom + 32)`. This is established in six sheets
across the codebase and is the canonical pattern.

---

## 4. Component Rules

### Rule 4.1 — Button Styles

**Primary action (FilledButton):**
```
backgroundColor: AppColors.accent
foregroundColor: AppColors.onAccent
padding: EdgeInsets.symmetric(vertical: 14)  [or 16 for full-width CTA]
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
```

**Destructive action (FilledButton):**
```
backgroundColor: AppColors.destructive
```
Destructive buttons appear in "Abandon", "Delete", and "Finish (workout)" contexts.

**Secondary / outline action (OutlinedButton):**
```
side: BorderSide(color: AppColors.divider)
foregroundColor: AppColors.textPrimary  or  AppColors.textSecondary
padding: EdgeInsets.symmetric(vertical: 14)
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
```

**Ghost / skip (TextButton):**
No border or background. Foreground color follows context (accent for positive skip,
textSecondary for neutral cancel, destructive for irreversible actions).

### Rule 4.2 — Card Container Style
Reusable card containers use:
```
color: AppColors.card
borderRadius: BorderRadius.circular(16)   [or 14 for secondary cards]
```
Use radius 16 for primary content cards (MetricCard, section containers).
Use radius 14 for workout template cards, schedule group containers, and bottom sheet
sub-containers. Avoid using both radii for visually equivalent containers in the same
screen.

### Rule 4.3 — Icon Badge / Avatar Style
Leading icon containers in list rows follow:
```
width: 36, height: 36
color: accentColor.withValues(alpha: 0.15)  [or 0.07 for de-emphasised]
borderRadius: BorderRadius.circular(10)
icon size: 18
```
This pattern is used identically in `HistorySection`, `HealthMetricDetailScreen`,
`SleepDetailScreen`, `BloodPressureDetailScreen`, and `HealthScreen`. Any new list row
with a leading icon must follow it.

### Rule 4.4 — Dismissible Delete Background
Swipe-to-delete containers use:
```
color: AppColors.destructive
icon: Icons.delete_rounded, color: AppColors.onAccent
borderRadius: matches the card it covers
```

### Rule 4.5 — Dialog (AlertDialog) Style
All `AlertDialog` instances use `backgroundColor: AppColors.card`.
Title: `TextStyle(color: AppColors.textPrimary)`.
Content: `TextStyle(color: AppColors.textSecondary)`.
Cancel action: `TextStyle(color: AppColors.textSecondary)`.
Primary action: `FilledButton` following Rule 4.1.

---

## 5. Reusable Widgets

### Rule 5.1 — MetricCard
Use `MetricCard` for any single-metric display with label, value, unit, optional subtitle,
accent color, and icon. Do not create ad-hoc equivalents.

### Rule 5.2 — TrendChart
Use `TrendChart` for any 30-point line sparkline on a `HealthEntry` series.

### Rule 5.3 — BodyCompositionOverviewChart
Use for multi-series body-composition charts (weight + fat + muscle). Not for generic
trend display.

### Rule 5.4 — HistorySection (named HistoryTile in CLAUDE.md)
Use `HistorySection` (from `lib/widgets/history_tile.dart`) for any scrollable list of
dated `HealthEntry` values with delta badges. Do not inline equivalent list-building logic
in screens.

### Rule 5.5 — Shared Workout Form Fields
`StepperField`, `WeightField`, and `RestTimeSelector` live in
`lib/widgets/workout_form_fields.dart` and are imported by both
`lib/screens/workout_detail_screen.dart` and `lib/screens/add_exercise_screen.dart`.
(Resolved.) Do not re-define these per-screen; use the shared widgets.

---

## 6. State Representation

### Rule 6.1 — Mandatory State Handling
Every screen with async data must visually handle: `loading`, `loaded`, `error`, and
`empty`. The `denied` state (health permission not granted) is an additional state where
applicable.

### Rule 6.2 — Loading State Visual
The loading state must show shimmer placeholder `MetricCard`s (via `isLoading: true`) for
screens that display `MetricCard`s, or a `CircularProgressIndicator(color: AppColors.accent)`
centred in the body for list-only screens.

### Rule 6.3 — Error State Visual
The error state must display: `Icons.error_outline` (size 64) with color
`AppColors.destructive`, an error title using `textTheme.titleLarge`, optional message
using `textTheme.bodySmall`, and a retry `FilledButton` following Rule 4.1.

---

## 7. Destructive / Danger Color (NEW RULE)

### Rule 7.1 — Destructive Color Usage
All destructive UI elements (delete actions, abandon dialogs, error icons, skip workout)
must use the single semantic constant `AppColors.destructive`. (Resolved — the former mix
of `Colors.red`, `Colors.redAccent`, `Colors.red.shade700`, and `Colors.red.shade900` has
been unified.)

---

## 8. Delta Badge Pattern (NEW RULE)

### Rule 8.1 — Delta Badge Colors
Delta badges showing increases/decreases in health metrics must use:
- Positive delta (increase): `AppColors.deltaPositiveColor` (red-ish — bad for fat/weight)
- Negative delta (decrease): `AppColors.deltaNegativeColor` (green-ish — good for fat/weight)

A single shared `DeltaBadge` widget in `lib/widgets/delta_badge.dart` implements this and is
used by both `HistorySection` and `HealthMetricDetailScreen`. (Resolved — the two former
private `_DeltaBadge` copies, including the dead `unit == '%'` conditional, have been
removed.) The `spaceBeforeUnit` flag controls `2.0 kg` vs `2.0%` formatting.

---

## 9. AppTheme Completeness (NEW RULE)

### Rule 9.1 — textTheme Must Cover All Named Styles In Use
`AppTheme.dark` defines `labelSmall` for caps section headers (Rule 2.3). (Resolved.)
Any new named style used by screens must be added to the central `TextTheme`.

### Rule 9.2 — BottomNavigationBarTheme Must Use AppColors
`BottomNavigationBarThemeData` references `AppColors.surface`, `AppColors.accent`, and
`AppColors.textSecondary` (Rule 1.3). (Resolved.)

---

## 10. Muscle-Group Colors (NEW RULE)

### Rule 10.1 — Exercise Muscle-Group Colors Must Be AppColors Constants
`AddExerciseScreen._colorForMuscleGroup()` maps muscle groups to `AppColors.muscleChest`,
`AppColors.muscleBack`, `AppColors.muscleLegs`, `AppColors.muscleShoulders`,
`AppColors.muscleBiceps`, `AppColors.muscleTriceps`, `AppColors.muscleCore`, and
`AppColors.muscleCardio`. (Resolved — no inline `Color(0x...)` literals remain.)

---

## 11. Apple Watch App (Native SwiftUI)

### Rule 11.1 — Watch App Uses System Colors Only
The Apple Watch app (`ios/FitnessWatch Watch App/`) is a native SwiftUI target and does not
share Flutter's `AppColors` system. It is correct to use SwiftUI semantic colors
(`.secondary`, `.primary`, `.red`, `.green`, `.blue`) and system materials
(`.ultraThinMaterial`). The watch app is **exempt** from Rules 1.1 and 1.2.

### Rule 11.2 — Watch Accent Colors Must Semantically Match iOS App
Where the watch app assigns a specific color to a concept (e.g. green for "complete set",
red for "Finish"), the hue must approximately match the iOS app's `AppColors.success` and
`AppColors.destructive`. Current implementation uses `.green` and `.red` which is
acceptable, but if the Flutter palette diverges, the watch colors must be updated in step.

---

## 12. Shared Health Display Helpers

### Rule 12.1 — Shared Logic Must Not Be Duplicated Across Screens
The `sevenDayChange()` and `groupSleepByNight()` helpers live in
`lib/utils/health_display_utils.dart` and are imported by `HomeScreen`, `DashboardScreen`,
and `HealthScreen`. (Resolved — the former per-screen `_get7DayChange()` /
`_groupSleepByNight()` copies have been removed.) New cross-screen display logic belongs in
a shared util, not copy-pasted.
