# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run on a connected device or simulator
flutter run

# Run all tests
flutter test

# Run a single test file
flutter test test/body_composition_import_test.dart

# Analyze (lint)
flutter analyze

# Install dependencies
flutter pub get
```

## Architecture

**Three-tab app** (`lib/main.dart`): `HomeScreen` (Metrics), `WorkoutsScreen`, `ScheduleScreen` — held in an `IndexedStack` inside `MainShell`.

**Layer structure:**

- `lib/models/` — plain Dart data classes with `toMap()`/`fromMap()` for SQLite I/O. No business logic. Key models: `workout.dart` (Exercise, TemplateExercise, WorkoutTemplate, SessionExercise, SetResult, WorkoutSession), `schedule.dart` (ScheduleEntry, UpcomingWorkout), `body_composition_entry.dart` (BodyCompositionEntry + chart helpers), `health_entry.dart` (HealthEntry, BodyMetrics).

- `lib/services/` — singleton services (all use `instance` factory pattern). Each holds a reference to `DatabaseHelper.instance.database`.
  - `DatabaseHelper` — SQLite via `sqflite`, schema version 4. Tables: `exercises`, `workout_templates`, `template_exercises`, `workout_sessions`, `session_exercises`, `set_results`, `schedule_entries`, `schedule_config`, `body_composition_entries`. Migrations run in `onUpgrade`; idempotent `CREATE TABLE IF NOT EXISTS` also runs in `onOpen` for tables added post-initial-creation.
  - `WorkoutService` — CRUD for templates and live sessions. Sessions have status: `active` | `completed` | `abandoned`.
  - `ScheduleService` — rotating schedule logic. Each `ScheduleEntry` has `cycleLength` (1 = every week, N = N-week rotation) and `cycleIndex` (0-based slot). An anchor Monday stored in `schedule_config` determines which calendar weeks map to which cycle slot.
  - `BodyCompositionService` — upsert-by-date strategy (one entry per day, `measured_at` has a UNIQUE constraint).
  - `HealthService` — stub; always grants permission and returns empty metrics. Intended extension point for HealthKit/Health Connect.

- `lib/screens/` — stateful widgets that own their data load lifecycle. Load pattern: call `setState(loading)` → await service → `setState(loaded/error)`. Navigation is imperative `Navigator.push` returning a `bool` to trigger reloads.

- `lib/widgets/` — reusable display components (`MetricCard`, `TrendChart`, `BodyCompositionOverviewChart`, `HistoryTile`).

- `lib/utils/body_composition_import.dart` — pure parser for tab-/multi-space-separated paste from spreadsheets. European date format `d.M.yyyy`. Throws `BodyCompositionImportParseException` on bad input.

- `lib/theme/app_theme.dart` — single dark `ThemeData` exposed as `AppTheme.dark`. Colors live in `AppColors` constants; use those instead of inline `Color(...)`.

## Key conventions

- All IDs are UUIDs generated with `uuid` package (`Uuid().v4()`).
- Dates are stored as milliseconds since epoch (integers) in SQLite.
- `BodyCompositionEntry.measuredAt` is always truncated to day precision before storage.
- `BodyMetrics` (from `health_entry.dart`) is the ViewModel that screens consume; it's built by `bodyMetricsFromEntries()` and optionally merged with `HealthService` data via `BodyMetrics.mergedWith()`.
- DB schema changes: bump `_databaseVersion`, add a branch to `_onUpgrade`, and if additive use `CREATE TABLE IF NOT EXISTS` / `ALTER TABLE` so `onOpen` stays safe.
