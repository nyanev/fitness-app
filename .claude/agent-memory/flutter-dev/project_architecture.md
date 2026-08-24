---
name: project-architecture
description: Layer structure, key files, service singleton patterns, DB schema, and app conventions for the fitness app
metadata:
  type: project
---

## App structure
Three (now four) tabs in `lib/main.dart` via `IndexedStack` in `MainShell`: Dashboard, Workouts, Schedule, Calendar.

## Service pattern
All services are singletons: `static final ServiceName instance = ServiceName._internal(); ServiceName._internal();`. They hold `Future<Database> get _db => DatabaseHelper.instance.database`.

## DatabaseHelper
- `lib/services/database_helper.dart`, schema version 4
- Tables: `exercises`, `workout_templates`, `template_exercises`, `workout_sessions`, `session_exercises`, `set_results`, `schedule_entries`, `schedule_config`, `schedule_exceptions`, `body_composition_entries`
- Migrations in `_onUpgrade`; post-initial tables also in `onOpen` with `CREATE TABLE IF NOT EXISTS`

## Key conventions
- All IDs: `Uuid().v4()` from `uuid` package
- Dates stored as epoch milliseconds (int) in SQLite
- `BodyCompositionEntry.measuredAt` truncated to day precision before storage
- `WorkoutSession` status: `active` | `completed` | `abandoned`
- Schedule rotation: `ScheduleEntry.cycleLength` (1=every week, N=N-week), `cycleIndex` (0-based). Anchor Monday in `schedule_config` maps calendar weeks to cycle slots.

## Screen load pattern
`_LoadState { idle, loading, loaded, error }` enum, `setState(loading)` → `await service` → `setState(loaded/error)`. RefreshIndicator with `color: AppColors.accent, backgroundColor: AppColors.card`.

## Colors
Always use `AppColors` constants from `lib/theme/app_theme.dart`. Never inline `Color(...)`.
`AppColors.success` = green (#34C759), `AppColors.warning` = orange (#FF9F0A), `AppColors.accent` = purple (#6C63FF), `AppColors.destructive` = red (#FF3B30).

## Flutter binary
Flutter is NOT available in the shell environment (not on PATH). Cannot run `flutter analyze` or `flutter pub get` from bash. The user must run these commands manually.
