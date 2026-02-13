import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/set_log.dart';
import '../models/user_prefs.dart';
import '../models/workout_log.dart';
import '../models/active_session.dart';
import 'local_store.dart';

class SharedPrefsStore implements LocalStore {
  static const _workoutsKey = 'workouts_json';
  static const _prefsKey = 'user_prefs_json';
  static const _activeSessionKey = 'active_session_json';

  @override
  Future<List<WorkoutLog>> fetchWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_workoutsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final workouts = <WorkoutLog>[];
    for (final entry in raw) {
      try {
        final data = jsonDecode(entry) as Map<String, dynamic>;
        workouts.add(_workoutFromJson(data));
      } catch (_) {
        // Skip corrupt entries.
      }
    }
    return workouts;
  }

  @override
  Future<void> saveWorkout(WorkoutLog log) async {
    final workouts = await fetchWorkouts();
    final updated = [_ensureId(log), ...workouts];
    await _persistWorkouts(updated);
  }

  @override
  Future<void> updateWorkout(WorkoutLog log) async {
    final workouts = await fetchWorkouts();
    final index = workouts.indexWhere(
      (entry) => entry.effectiveId == log.effectiveId,
    );
    if (index == -1) {
      return;
    }
    final existing = workouts[index];
    final resolvedId = (log.id != null && log.id!.isNotEmpty)
        ? log.id!
        : (existing.id ?? log.effectiveId);
    final updated = List<WorkoutLog>.from(workouts);
    updated[index] = _withId(log, resolvedId);
    await _persistWorkouts(updated);
  }

  @override
  Future<void> deleteWorkout(String id) async {
    final workouts = await fetchWorkouts();
    final updated = workouts
        .where((entry) => entry.effectiveId != id)
        .toList();
    await _persistWorkouts(updated);
  }

  @override
  Future<UserPrefs> fetchPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return UserPrefs.empty();
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return UserPrefs.fromJson(data);
    } catch (_) {
      return UserPrefs.empty();
    }
  }

  @override
  Future<void> savePrefs(UserPrefs prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_prefsKey, jsonEncode(prefs.toJson()));
  }

  @override
  Future<ActiveSession?> fetchActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return ActiveSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveActiveSession(ActiveSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeSessionKey, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clearActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeSessionKey);
  }

  // -- helpers ---------------------------------------------------------------

  Future<void> _persistWorkouts(List<WorkoutLog> workouts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = workouts.map((w) => jsonEncode(w.toJson())).toList();
    await prefs.setStringList(_workoutsKey, encoded);
  }

  WorkoutLog _ensureId(WorkoutLog log) {
    if (log.id != null && log.id!.isNotEmpty) {
      return log;
    }
    return _withId(log, log.effectiveId);
  }

  WorkoutLog _withId(WorkoutLog log, String id) {
    return WorkoutLog(
      id: id,
      name: log.name,
      summary: log.summary,
      aiComment: log.aiComment,
      date: log.date,
      sets: log.sets,
      durationMinutes: log.durationMinutes,
    );
  }

  WorkoutLog _workoutFromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] as List<dynamic>? ?? [];
    final sets = rawSets
        .whereType<Map<String, dynamic>>()
        .map((s) => SetLog(
              exerciseName: (s['exerciseName'] ?? '').toString(),
              reps: int.tryParse((s['reps'] ?? '0').toString()) ?? 0,
              weight:
                  double.tryParse((s['weight'] ?? '0').toString()) ?? 0,
              rpe: s['rpe'] != null
                  ? double.tryParse(s['rpe'].toString())
                  : null,
              notes: (s['notes'] ?? '').toString(),
              type: parseExerciseType(s['type']?.toString()),
              durationMinutes: s['durationMinutes'] != null
                  ? int.tryParse(s['durationMinutes'].toString())
                  : null,
            ))
        .toList();

    return WorkoutLog(
      id: json['id']?.toString(),
      name: (json['name'] ?? 'Workout').toString(),
      summary: json['summary']?.toString(),
      aiComment: json['aiComment']?.toString(),
      date: DateTime.tryParse((json['date'] ?? '').toString()) ??
          DateTime.now(),
      sets: sets,
      durationMinutes: json['durationMinutes'] != null
          ? int.tryParse(json['durationMinutes'].toString())
          : null,
    );
  }
}
