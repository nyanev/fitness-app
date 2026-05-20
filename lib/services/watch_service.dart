import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/workout.dart';
import 'workout_service.dart';

class WatchService {
  static final WatchService instance = WatchService._();
  WatchService._();

  static const _channel = MethodChannel('co.yanev.fitnessApp/watch');
  static const _events = EventChannel('co.yanev.fitnessApp/watch_events');

  StreamSubscription<dynamic>? _sub;

  void init() {
    _sub = _events.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> syncTemplates(List<WorkoutTemplate> templates) async {
    try {
      final data = templates
          .map((t) => {
                'id': t.id,
                'name': t.name,
                'exercises': t.exercises
                    .map((e) => {
                          'id': e.id,
                          'name': e.exerciseName,
                          'targetSets': e.sets,
                          'targetReps': e.reps,
                          'targetWeight': e.weight,
                          'restSeconds': e.restSeconds,
                          'orderIndex': e.orderIndex,
                        })
                    .toList(),
              })
          .toList();
      await _channel.invokeMethod<void>(
          'syncTemplates', {'templates': jsonEncode(data)});
    } catch (_) {}
  }

  void _handleEvent(dynamic event) {
    try {
      final map = Map<String, dynamic>.from(event as Map);
      switch (map['action'] as String?) {
        case 'start_workout':
          _handleStart(map);
        case 'complete_set':
          _handleSet(map);
        case 'finish_workout':
          _handleFinish(map);
      }
    } catch (_) {}
  }

  void _handleStart(Map<String, dynamic> msg) async {
    final sessionId = msg['sessionId'] as String?;
    final templateId = msg['templateId'] as String?;
    final startedAtMs = (msg['startedAt'] as num?)?.toInt();
    if (sessionId == null || templateId == null) return;

    final template = await WorkoutService.instance.getWorkoutTemplate(templateId);
    if (template == null) return;

    final startedAt = startedAtMs != null
        ? DateTime.fromMillisecondsSinceEpoch(startedAtMs)
        : DateTime.now();

    await WorkoutService.instance.startWorkoutSessionWithId(
      template: template,
      sessionId: sessionId,
      startedAt: startedAt,
    );
  }

  void _handleSet(Map<String, dynamic> msg) async {
    final sessionId = msg['sessionId'] as String?;
    final exerciseIndex = (msg['exerciseIndex'] as num?)?.toInt();
    final setNumber = (msg['setNumber'] as num?)?.toInt();
    final reps = (msg['reps'] as num?)?.toInt() ?? 0;
    final weight = (msg['weight'] as num?)?.toDouble() ?? 0.0;
    if (sessionId == null || exerciseIndex == null || setNumber == null) return;

    await WorkoutService.instance.recordSetByExerciseIndex(
      sessionId: sessionId,
      exerciseIndex: exerciseIndex,
      setNumber: setNumber,
      reps: reps,
      weight: weight,
    );
  }

  void _handleFinish(Map<String, dynamic> msg) async {
    final sessionId = msg['sessionId'] as String?;
    if (sessionId == null) return;
    // Watch already saved to HealthKit via HKWorkoutBuilder — don't double-write.
    await WorkoutService.instance.completeSession(sessionId);
  }
}
