# Fitness App

A personal fitness tracking app built with Flutter. Tracks workouts, body composition, and health metrics with a local SQLite database.

## Features

- **Workouts** — create and manage workout templates with exercises, log live sessions with sets and reps
- **Schedule** — rotating weekly schedule with configurable cycle length and anchor-based week mapping
- **Body Composition** — track weight, body fat, and other metrics over time with trend charts; import from spreadsheet paste
- **Health Metrics** — overview dashboard with metric cards and charts

## Getting Started

```bash
# Install dependencies
flutter pub get

# Run on a connected device or simulator
flutter run

# Run tests
flutter test

# Lint
flutter analyze
```

## Architecture

Three-tab app (`HomeScreen`, `WorkoutsScreen`, `ScheduleScreen`) held in an `IndexedStack` inside `MainShell`.

| Layer | Location | Purpose |
|---|---|---|
| Models | `lib/models/` | Plain Dart data classes with `toMap()`/`fromMap()` for SQLite I/O |
| Services | `lib/services/` | Singleton services (`.instance`) wrapping all database access |
| Screens | `lib/screens/` | Stateful widgets owning their data load lifecycle |
| Widgets | `lib/widgets/` | Reusable display components (`MetricCard`, `TrendChart`, etc.) |
| Utils | `lib/utils/` | Pure helpers (e.g. body composition CSV parser) |
| Theme | `lib/theme/app_theme.dart` | Single dark `ThemeData`; use `AppColors` constants |

## Database

SQLite via `sqflite`, schema version 4. Tables: `exercises`, `workout_templates`, `template_exercises`, `workout_sessions`, `session_exercises`, `set_results`, `schedule_entries`, `schedule_config`, `body_composition_entries`.

To add a schema change: bump `_databaseVersion`, add a branch to `_onUpgrade`, and use `CREATE TABLE IF NOT EXISTS` / `ALTER TABLE` so `onOpen` stays idempotent.

## Key Conventions

- All IDs are UUIDs (`uuid` package).
- Dates are stored as milliseconds since epoch.
- `BodyCompositionEntry.measuredAt` is truncated to day precision before storage (UNIQUE constraint per day).
- Body composition import expects tab-/multi-space-separated text with European date format (`d.M.yyyy`).
