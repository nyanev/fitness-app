import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const String _databaseName = 'fitness_app.db';
  static const int _databaseVersion = 5;

  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._internal();

  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // Runs every time the database is opened (including hot reloads in dev).
      // CREATE TABLE IF NOT EXISTS is idempotent, so this safely fills in any
      // tables that were added after the database was first created.
      onOpen: (db) async {
        await _createScheduleTables(db);
        await _migrateScheduleV3IfNeeded(db);
        await _createBodyCompositionTable(db);
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        muscle_group TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE template_exercises (
        id TEXT PRIMARY KEY,
        template_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        exercise_name TEXT NOT NULL,
        muscle_group TEXT,
        sets INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL,
        rest_seconds INTEGER NOT NULL DEFAULT 60,
        order_index INTEGER NOT NULL,
        FOREIGN KEY (template_id) REFERENCES workout_templates (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_sessions (
        id TEXT PRIMARY KEY,
        template_id TEXT NOT NULL,
        template_name TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        completed_at INTEGER,
        status TEXT NOT NULL DEFAULT 'active'
      )
    ''');

    await db.execute('''
      CREATE TABLE session_exercises (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        exercise_name TEXT NOT NULL,
        target_sets INTEGER NOT NULL,
        target_reps INTEGER NOT NULL,
        target_weight REAL,
        rest_seconds INTEGER NOT NULL DEFAULT 60,
        order_index INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES workout_sessions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE set_results (
        id TEXT PRIMARY KEY,
        session_exercise_id TEXT NOT NULL,
        set_number INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL NOT NULL,
        completed_at INTEGER NOT NULL,
        FOREIGN KEY (session_exercise_id) REFERENCES session_exercises (id) ON DELETE CASCADE
      )
    ''');

    await _createScheduleTables(db);
    await _createBodyCompositionTable(db);
    await _insertDefaultExercises(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createScheduleTables(db);
    }
    if (oldVersion < 3) {
      await _migrateScheduleV3IfNeeded(db);
    }
    if (oldVersion < 4) {
      await _createBodyCompositionTable(db);
    }
    if (oldVersion < 5) {
      await _insertAdditionalExercises(db);
    }
  }

  Future<void> _createBodyCompositionTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS body_composition_entries (
        id TEXT PRIMARY KEY,
        measured_at INTEGER NOT NULL UNIQUE,
        weight_kg REAL NOT NULL,
        body_fat_pct REAL,
        body_fat_kg REAL,
        skeletal_muscle_mass_pct REAL,
        skeletal_muscle_mass_kg REAL,
        fat_free_mass_kg REAL,
        body_water_pct REAL,
        visceral_fat REAL,
        bone_mineral_kg REAL,
        protein_pct REAL
      )
    ''');
  }

  Future<void> _createScheduleTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schedule_entries (
        id TEXT PRIMARY KEY,
        template_id TEXT NOT NULL,
        template_name TEXT NOT NULL,
        day_of_week INTEGER NOT NULL,
        week_pattern TEXT NOT NULL DEFAULT 'every',
        cycle_length INTEGER NOT NULL DEFAULT 1,
        cycle_index INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS schedule_config (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// Adds [cycle_length] / [cycle_index] and back-fills from legacy [week_pattern]
  /// once (when columns are first added), so we do not overwrite flexible schedules on every open.
  Future<void> _migrateScheduleV3IfNeeded(Database db) async {
    final info = await db.rawQuery('PRAGMA table_info(schedule_entries)');
    final names = info.map((c) => c['name'] as String).toSet();
    var addedColumns = false;
    if (!names.contains('cycle_length')) {
      await db.execute(
        'ALTER TABLE schedule_entries ADD COLUMN cycle_length INTEGER NOT NULL DEFAULT 1',
      );
      addedColumns = true;
    }
    if (!names.contains('cycle_index')) {
      await db.execute(
        'ALTER TABLE schedule_entries ADD COLUMN cycle_index INTEGER NOT NULL DEFAULT 0',
      );
      addedColumns = true;
    }
    if (!addedColumns) return;

    await db.rawUpdate('''
      UPDATE schedule_entries SET cycle_length = 1, cycle_index = 0
      WHERE week_pattern = 'every'
    ''');
    await db.rawUpdate('''
      UPDATE schedule_entries SET cycle_length = 2, cycle_index = 0
      WHERE week_pattern = 'week_a'
    ''');
    await db.rawUpdate('''
      UPDATE schedule_entries SET cycle_length = 2, cycle_index = 1
      WHERE week_pattern = 'week_b'
    ''');
  }

  Future<void> _insertDefaultExercises(Database db) async {
    const exercises = [
      ('bench_press_default', 'Bench Press', 'Chest'),
      ('incline_bench_default', 'Incline Bench Press', 'Chest'),
      ('cable_fly_default', 'Cable Fly', 'Chest'),
      ('chest_dip_default', 'Chest Dip', 'Chest'),
      ('squat_default', 'Squat', 'Legs'),
      ('leg_press_default', 'Leg Press', 'Legs'),
      ('romanian_deadlift_default', 'Romanian Deadlift', 'Legs'),
      ('leg_curl_default', 'Leg Curl', 'Legs'),
      ('leg_extension_default', 'Leg Extension', 'Legs'),
      ('calf_raise_default', 'Calf Raise', 'Legs'),
      ('deadlift_default', 'Deadlift', 'Back'),
      ('pull_up_default', 'Pull-up', 'Back'),
      ('barbell_row_default', 'Barbell Row', 'Back'),
      ('lat_pulldown_default', 'Lat Pulldown', 'Back'),
      ('seated_row_default', 'Seated Cable Row', 'Back'),
      ('overhead_press_default', 'Overhead Press', 'Shoulders'),
      ('lateral_raise_default', 'Lateral Raise', 'Shoulders'),
      ('face_pull_default', 'Face Pull', 'Shoulders'),
      ('dumbbell_curl_default', 'Dumbbell Curl', 'Biceps'),
      ('hammer_curl_default', 'Hammer Curl', 'Biceps'),
      ('tricep_dip_default', 'Tricep Dip', 'Triceps'),
      ('skullcrusher_default', 'Skull Crusher', 'Triceps'),
      ('plank_default', 'Plank', 'Core'),
      ('ab_crunch_default', 'Ab Crunch', 'Core'),
      ('russian_twist_default', 'Russian Twist', 'Core'),
    ];

    final batch = db.batch();
    for (final (id, name, group) in exercises) {
      batch.insert('exercises', {
        'id': id,
        'name': name,
        'muscle_group': group,
      });
    }
    await batch.commit(noResult: true);
    await _insertAdditionalExercises(db);
  }

  Future<void> _insertAdditionalExercises(Database db) async {
    const exercises = [
      // Chest
      ('push_up_default', 'Push-up', 'Chest'),
      ('dumbbell_fly_default', 'Dumbbell Fly', 'Chest'),
      ('decline_bench_default', 'Decline Bench Press', 'Chest'),
      ('pec_deck_default', 'Pec Deck', 'Chest'),
      // Back
      ('tbar_row_default', 'T-Bar Row', 'Back'),
      ('single_arm_row_default', 'Single-Arm Dumbbell Row', 'Back'),
      ('chin_up_default', 'Chin-up', 'Back'),
      ('hyperextension_default', 'Hyperextension', 'Back'),
      ('good_morning_default', 'Good Morning', 'Back'),
      // Legs
      ('bulgarian_split_squat_default', 'Bulgarian Split Squat', 'Legs'),
      ('lunges_default', 'Lunges', 'Legs'),
      ('hip_thrust_default', 'Hip Thrust', 'Legs'),
      ('hack_squat_default', 'Hack Squat', 'Legs'),
      ('nordic_curl_default', 'Nordic Curl', 'Legs'),
      ('glute_bridge_default', 'Glute Bridge', 'Legs'),
      // Shoulders
      ('arnold_press_default', 'Arnold Press', 'Shoulders'),
      ('rear_delt_fly_default', 'Rear Delt Fly', 'Shoulders'),
      ('upright_row_default', 'Upright Row', 'Shoulders'),
      ('front_raise_default', 'Front Raise', 'Shoulders'),
      ('cable_lateral_raise_default', 'Cable Lateral Raise', 'Shoulders'),
      // Biceps
      ('barbell_curl_default', 'Barbell Curl', 'Biceps'),
      ('preacher_curl_default', 'Preacher Curl', 'Biceps'),
      ('cable_curl_default', 'Cable Curl', 'Biceps'),
      ('concentration_curl_default', 'Concentration Curl', 'Biceps'),
      // Triceps
      ('tricep_pushdown_default', 'Tricep Pushdown', 'Triceps'),
      ('overhead_tricep_ext_default', 'Overhead Tricep Extension', 'Triceps'),
      ('close_grip_bench_default', 'Close-Grip Bench Press', 'Triceps'),
      ('diamond_pushup_default', 'Diamond Push-up', 'Triceps'),
      // Core
      ('leg_raise_default', 'Leg Raise', 'Core'),
      ('hanging_knee_raise_default', 'Hanging Knee Raise', 'Core'),
      ('bicycle_crunch_default', 'Bicycle Crunch', 'Core'),
      ('dead_bug_default', 'Dead Bug', 'Core'),
      ('cable_crunch_default', 'Cable Crunch', 'Core'),
      ('side_plank_default', 'Side Plank', 'Core'),
      // Cardio
      ('running_default', 'Running', 'Cardio'),
      ('cycling_default', 'Cycling', 'Cardio'),
      ('jump_rope_default', 'Jump Rope', 'Cardio'),
      ('rowing_machine_default', 'Rowing Machine', 'Cardio'),
      ('stair_climber_default', 'Stair Climber', 'Cardio'),
      ('swimming_default', 'Swimming', 'Cardio'),
    ];

    final batch = db.batch();
    for (final (id, name, group) in exercises) {
      batch.insert(
        'exercises',
        {'id': id, 'name': name, 'muscle_group': group},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }
}
