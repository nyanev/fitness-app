class Exercise {
  final String id;
  final String name;
  final String? muscleGroup;

  const Exercise({
    required this.id,
    required this.name,
    this.muscleGroup,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'muscle_group': muscleGroup,
      };

  factory Exercise.fromMap(Map<String, dynamic> map) => Exercise(
        id: map['id'] as String,
        name: map['name'] as String,
        muscleGroup: map['muscle_group'] as String?,
      );
}

class TemplateExercise {
  final String id;
  final String templateId;
  final String exerciseId;
  final String exerciseName;
  final String? muscleGroup;
  final int sets;
  final int reps;
  final double? weight;
  final int restSeconds;
  final int orderIndex;

  const TemplateExercise({
    required this.id,
    required this.templateId,
    required this.exerciseId,
    required this.exerciseName,
    this.muscleGroup,
    required this.sets,
    required this.reps,
    this.weight,
    required this.restSeconds,
    required this.orderIndex,
  });

  TemplateExercise copyWith({
    int? sets,
    int? reps,
    double? weight,
    int? restSeconds,
  }) =>
      TemplateExercise(
        id: id,
        templateId: templateId,
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        muscleGroup: muscleGroup,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        weight: weight ?? this.weight,
        restSeconds: restSeconds ?? this.restSeconds,
        orderIndex: orderIndex,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'template_id': templateId,
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'muscle_group': muscleGroup,
        'sets': sets,
        'reps': reps,
        'weight': weight,
        'rest_seconds': restSeconds,
        'order_index': orderIndex,
      };

  factory TemplateExercise.fromMap(Map<String, dynamic> map) => TemplateExercise(
        id: map['id'] as String,
        templateId: map['template_id'] as String,
        exerciseId: map['exercise_id'] as String,
        exerciseName: map['exercise_name'] as String,
        muscleGroup: map['muscle_group'] as String?,
        sets: map['sets'] as int,
        reps: map['reps'] as int,
        weight: (map['weight'] as num?)?.toDouble(),
        restSeconds: map['rest_seconds'] as int,
        orderIndex: map['order_index'] as int,
      );
}

class WorkoutTemplate {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final List<TemplateExercise> exercises;

  const WorkoutTemplate({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.exercises,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory WorkoutTemplate.fromMap(
    Map<String, dynamic> map,
    List<Map<String, dynamic>> exerciseMaps,
  ) =>
      WorkoutTemplate(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        exercises: exerciseMaps.map(TemplateExercise.fromMap).toList(),
      );
}

enum SessionStatus { active, completed, abandoned }

class SetResult {
  final String id;
  final String sessionExerciseId;
  final int setNumber;
  final int reps;
  final double weight;
  final DateTime completedAt;

  const SetResult({
    required this.id,
    required this.sessionExerciseId,
    required this.setNumber,
    required this.reps,
    required this.weight,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_exercise_id': sessionExerciseId,
        'set_number': setNumber,
        'reps': reps,
        'weight': weight,
        'completed_at': completedAt.millisecondsSinceEpoch,
      };

  factory SetResult.fromMap(Map<String, dynamic> map) => SetResult(
        id: map['id'] as String,
        sessionExerciseId: map['session_exercise_id'] as String,
        setNumber: map['set_number'] as int,
        reps: map['reps'] as int,
        weight: (map['weight'] as num).toDouble(),
        completedAt:
            DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int),
      );
}

class SessionExercise {
  final String id;
  final String sessionId;
  final String exerciseId;
  final String exerciseName;
  final int targetSets;
  final int targetReps;
  final double? targetWeight;
  final int restSeconds;
  final int orderIndex;
  final List<SetResult> completedSets;

  const SessionExercise({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.exerciseName,
    required this.targetSets,
    required this.targetReps,
    this.targetWeight,
    required this.restSeconds,
    required this.orderIndex,
    required this.completedSets,
  });

  bool get isCompleted => completedSets.length >= targetSets;

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'target_sets': targetSets,
        'target_reps': targetReps,
        'target_weight': targetWeight,
        'rest_seconds': restSeconds,
        'order_index': orderIndex,
      };

  factory SessionExercise.fromMap(
    Map<String, dynamic> map,
    List<Map<String, dynamic>> setMaps,
  ) =>
      SessionExercise(
        id: map['id'] as String,
        sessionId: map['session_id'] as String,
        exerciseId: map['exercise_id'] as String,
        exerciseName: map['exercise_name'] as String,
        targetSets: map['target_sets'] as int,
        targetReps: map['target_reps'] as int,
        targetWeight: (map['target_weight'] as num?)?.toDouble(),
        restSeconds: map['rest_seconds'] as int,
        orderIndex: map['order_index'] as int,
        completedSets: setMaps.map(SetResult.fromMap).toList(),
      );
}

class WorkoutSession {
  final String id;
  final String templateId;
  final String templateName;
  final DateTime startedAt;
  final DateTime? completedAt;
  final SessionStatus status;
  final List<SessionExercise> exercises;

  const WorkoutSession({
    required this.id,
    required this.templateId,
    required this.templateName,
    required this.startedAt,
    this.completedAt,
    required this.status,
    required this.exercises,
  });

  Duration? get duration => completedAt?.difference(startedAt);

  int get totalSetsCompleted =>
      exercises.fold(0, (sum, e) => sum + e.completedSets.length);

  double get totalVolume => exercises.fold(
        0.0,
        (sum, e) => sum +
            e.completedSets.fold(
              0.0,
              (s, set) => s + set.weight * set.reps,
            ),
      );

  factory WorkoutSession.fromMap(
    Map<String, dynamic> map,
    List<SessionExercise> exercises,
  ) {
    final statusStr = map['status'] as String;
    final status = SessionStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => SessionStatus.active,
    );
    return WorkoutSession(
      id: map['id'] as String,
      templateId: map['template_id'] as String,
      templateName: map['template_name'] as String,
      startedAt:
          DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
          : null,
      status: status,
      exercises: exercises,
    );
  }
}
