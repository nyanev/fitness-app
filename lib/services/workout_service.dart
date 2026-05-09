import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/workout.dart';
import 'database_helper.dart';

class WorkoutService {
  static final WorkoutService instance = WorkoutService._internal();
  WorkoutService._internal();

  final _uuid = const Uuid();

  Future<Database> get _db => DatabaseHelper.instance.database;

  // ── Exercises ─────────────────────────────────────────────────────────────

  Future<List<Exercise>> getExercises() async {
    final db = await _db;
    final maps = await db.query('exercises', orderBy: 'name ASC');
    return maps.map(Exercise.fromMap).toList();
  }

  Future<Exercise> createExercise(String name, {String? muscleGroup}) async {
    final db = await _db;
    final exercise = Exercise(
      id: _uuid.v4(),
      name: name,
      muscleGroup: muscleGroup,
    );
    await db.insert('exercises', exercise.toMap());
    return exercise;
  }

  // ── Templates ─────────────────────────────────────────────────────────────

  Future<List<WorkoutTemplate>> getWorkoutTemplates() async {
    final db = await _db;
    final templateMaps =
        await db.query('workout_templates', orderBy: 'created_at DESC');
    final templates = <WorkoutTemplate>[];
    for (final templateMap in templateMaps) {
      final id = templateMap['id'] as String;
      final exerciseMaps = await db.query(
        'template_exercises',
        where: 'template_id = ?',
        whereArgs: [id],
        orderBy: 'order_index ASC',
      );
      templates.add(WorkoutTemplate.fromMap(templateMap, exerciseMaps));
    }
    return templates;
  }

  Future<WorkoutTemplate?> getWorkoutTemplate(String id) async {
    final db = await _db;
    final templateMaps = await db.query(
      'workout_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (templateMaps.isEmpty) return null;
    final exerciseMaps = await db.query(
      'template_exercises',
      where: 'template_id = ?',
      whereArgs: [id],
      orderBy: 'order_index ASC',
    );
    return WorkoutTemplate.fromMap(templateMaps.first, exerciseMaps);
  }

  Future<WorkoutTemplate> createWorkoutTemplate(
    String name, {
    String? description,
  }) async {
    final db = await _db;
    final template = WorkoutTemplate(
      id: _uuid.v4(),
      name: name,
      description: description,
      createdAt: DateTime.now(),
      exercises: [],
    );
    await db.insert('workout_templates', template.toMap());
    return template;
  }

  Future<void> updateWorkoutTemplate(
    String id, {
    String? name,
    String? description,
  }) async {
    final db = await _db;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (updates.isNotEmpty) {
      await db.update(
        'workout_templates',
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> deleteWorkoutTemplate(String id) async {
    final db = await _db;
    await db.delete(
      'template_exercises',
      where: 'template_id = ?',
      whereArgs: [id],
    );
    await db.delete('workout_templates', where: 'id = ?', whereArgs: [id]);
  }

  Future<TemplateExercise> addExerciseToTemplate({
    required String templateId,
    required String exerciseId,
    required String exerciseName,
    String? muscleGroup,
    required int sets,
    required int reps,
    double? weight,
    int restSeconds = 60,
  }) async {
    final db = await _db;
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM template_exercises WHERE template_id = ?',
      [templateId],
    );
    final orderIndex = countResult.first['count'] as int;
    final te = TemplateExercise(
      id: _uuid.v4(),
      templateId: templateId,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      muscleGroup: muscleGroup,
      sets: sets,
      reps: reps,
      weight: weight,
      restSeconds: restSeconds,
      orderIndex: orderIndex,
    );
    await db.insert('template_exercises', te.toMap());
    return te;
  }

  Future<void> updateTemplateExercise(
    String id, {
    int? sets,
    int? reps,
    double? weight,
    bool clearWeight = false,
    int? restSeconds,
  }) async {
    final db = await _db;
    final updates = <String, dynamic>{};
    if (sets != null) updates['sets'] = sets;
    if (reps != null) updates['reps'] = reps;
    if (clearWeight) {
      updates['weight'] = null;
    } else if (weight != null) {
      updates['weight'] = weight;
    }
    if (restSeconds != null) updates['rest_seconds'] = restSeconds;
    if (updates.isNotEmpty) {
      await db.update(
        'template_exercises',
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> removeExerciseFromTemplate(String templateExerciseId) async {
    final db = await _db;
    await db.delete(
      'template_exercises',
      where: 'id = ?',
      whereArgs: [templateExerciseId],
    );
  }

  // ── Sessions ───────────────────────────────────────────────────────────────

  Future<WorkoutSession> startWorkoutSession(WorkoutTemplate template) async {
    final db = await _db;
    final sessionId = _uuid.v4();
    final startedAt = DateTime.now();

    await db.insert('workout_sessions', {
      'id': sessionId,
      'template_id': template.id,
      'template_name': template.name,
      'started_at': startedAt.millisecondsSinceEpoch,
      'status': 'active',
    });

    final sessionExercises = <SessionExercise>[];
    for (final te in template.exercises) {
      final seId = _uuid.v4();
      final se = SessionExercise(
        id: seId,
        sessionId: sessionId,
        exerciseId: te.exerciseId,
        exerciseName: te.exerciseName,
        targetSets: te.sets,
        targetReps: te.reps,
        targetWeight: te.weight,
        restSeconds: te.restSeconds,
        orderIndex: te.orderIndex,
        completedSets: [],
      );
      await db.insert('session_exercises', se.toMap());
      sessionExercises.add(se);
    }

    return WorkoutSession(
      id: sessionId,
      templateId: template.id,
      templateName: template.name,
      startedAt: startedAt,
      status: SessionStatus.active,
      exercises: sessionExercises,
    );
  }

  Future<SetResult> recordSet({
    required String sessionExerciseId,
    required int setNumber,
    required int reps,
    required double weight,
  }) async {
    final db = await _db;
    final result = SetResult(
      id: _uuid.v4(),
      sessionExerciseId: sessionExerciseId,
      setNumber: setNumber,
      reps: reps,
      weight: weight,
      completedAt: DateTime.now(),
    );
    await db.insert('set_results', result.toMap());
    return result;
  }

  Future<WorkoutSession?> getActiveSession() async {
    final db = await _db;
    final sessionMaps = await db.query(
      'workout_sessions',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (sessionMaps.isEmpty) return null;
    return _buildSession(sessionMaps.first);
  }

  Future<WorkoutSession> completeSession(String sessionId) async {
    final db = await _db;
    final completedAt = DateTime.now();
    await db.update(
      'workout_sessions',
      {
        'status': 'completed',
        'completed_at': completedAt.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    final session = await _buildSessionById(sessionId);
    return session!;
  }

  Future<void> abandonSession(String sessionId) async {
    final db = await _db;
    await db.update(
      'workout_sessions',
      {'status': 'abandoned'},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<WorkoutSession>> getCompletedSessions() async {
    final db = await _db;
    final sessionMaps = await db.query(
      'workout_sessions',
      where: 'status = ?',
      whereArgs: ['completed'],
      orderBy: 'started_at DESC',
    );
    final sessions = <WorkoutSession>[];
    for (final map in sessionMaps) {
      sessions.add(await _buildSession(map));
    }
    return sessions;
  }

  Future<WorkoutSession?> _buildSessionById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'workout_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return _buildSession(maps.first);
  }

  Future<WorkoutSession> _buildSession(
    Map<String, dynamic> sessionMap,
  ) async {
    final db = await _db;
    final sessionId = sessionMap['id'] as String;

    final exerciseMaps = await db.query(
      'session_exercises',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'order_index ASC',
    );

    final sessionExercises = <SessionExercise>[];
    for (final exMap in exerciseMaps) {
      final seId = exMap['id'] as String;
      final setMaps = await db.query(
        'set_results',
        where: 'session_exercise_id = ?',
        whereArgs: [seId],
        orderBy: 'set_number ASC',
      );
      sessionExercises.add(SessionExercise.fromMap(exMap, setMaps));
    }

    return WorkoutSession.fromMap(sessionMap, sessionExercises);
  }
}
