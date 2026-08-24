---
name: calendar-feature
description: Calendar tab (4th tab) implementation — getScheduledWorkoutsInRange, day-state logic, table_calendar setup
metadata:
  type: project
---

## New files
- `lib/screens/calendar_screen.dart` — CalendarScreen StatefulWidget (4th tab)

## Modified files
- `pubspec.yaml` — added `table_calendar: ^3.1.2` (compatible with existing `intl: ^0.20.2`)
- `lib/services/schedule_service.dart` — added `getScheduledWorkoutsInRange(DateTime start, DateTime end)`, refactored `getUpcomingWorkouts` to delegate to it
- `lib/main.dart` — added CalendarScreen to `_screens`, added 4th BottomNavigationBarItem, set `type: BottomNavigationBarType.fixed`, changed Schedule icon to `Icons.event_repeat_outlined`/`Icons.event_repeat`

## getScheduledWorkoutsInRange
Iterates normalised days from `start` to `end` inclusive via a while loop (`while (!date.isAfter(normEnd))`). Uses same `_entryMatchesDate`, `_getExceptionsMap`, `_normalise` private helpers. Move exceptions only emitted if new date is within [normStart, normEnd]. Uses `addedMovedKeys` set for dedup.

**Why:** `getUpcomingWorkouts` was future-only; calendar needs past history too.

## Day-state precedence in CalendarScreen
1. **Trained** (completed session exists) → `AppColors.success` dot
2. **Missed** (planned + before today + not trained) → `AppColors.warning` dot
3. **Planned** (scheduled, today or future, not trained) → `AppColors.accent` dot
Today is never "missed".

## Data loading window
`_firstDay` = now - 180 days, `_lastDay` = now + 60 days. Static final fields computed once at class load time.

## table_calendar integration notes
- `markerBuilder` returns `Widget?` (single widget, placed in cell's Stack by table_calendar). `Positioned(bottom: 4, ...)` is correct here.
- `CalendarFormat.month` fixed, `formatButtonVisible: false` hides format toggle.
- `startingDayOfWeek: StartingDayOfWeek.monday` to match schedule convention.
