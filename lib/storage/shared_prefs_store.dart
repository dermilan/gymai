import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_card_config.dart';
import '../models/user_prefs.dart';
import '../models/workout.dart';
import 'local_store.dart';

class SharedPrefsStore implements LocalStore {
  static const _workoutsKey = 'workouts_json';
  static const _prefsKey = 'user_prefs_json';
  static const _activeSessionKey = 'active_session_json';
  static const _lastSeenHistoryCountKey = 'last_seen_history_count';
  static const _dashboardLayoutKey = 'dashboard_layout_json';

  @override
  Future<List<Workout>> fetchWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_workoutsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final workouts = <Workout>[];
    for (final entry in raw) {
      try {
        final data = jsonDecode(entry) as Map<String, dynamic>;
        workouts.add(_workoutFromJson(data));
      } catch (_) {
        // Skip corrupt entries.
      }
    }
    // Sort by date descending (newest first) to match DatabaseStore behavior
    workouts.sort((a, b) => b.date.compareTo(a.date));
    return workouts;
  }

  @override
  Future<void> saveWorkout(Workout workout) async {
    final workouts = await fetchWorkouts();
    final updated = [_ensureId(workout), ...workouts];
    await _persistWorkouts(updated);
  }

  @override
  Future<void> updateWorkout(Workout workout) async {
    final workouts = await fetchWorkouts();
    final index = workouts.indexWhere(
      (entry) => entry.effectiveId == workout.effectiveId,
    );
    if (index == -1) {
      return;
    }
    final existing = workouts[index];
    final resolvedId = (workout.id != null && workout.id!.isNotEmpty)
        ? workout.id!
        : (existing.id ?? workout.effectiveId);
    final updated = List<Workout>.from(workouts);
    updated[index] = workout.copyWith(id: resolvedId);
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
  Future<Workout?> fetchActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Workout.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveActiveSession(Workout session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeSessionKey, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clearActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeSessionKey);
  }

  @override
  Future<int> getUnseenHistoryCount() async {
    final prefs = await SharedPreferences.getInstance();
    final workouts = await fetchWorkouts();
    final completedCount = workouts.where((w) => w.status == WorkoutStatus.completed).length;
    final lastSeenCount = prefs.getInt(_lastSeenHistoryCountKey) ?? 0;
    return (completedCount - lastSeenCount).clamp(0, completedCount);
  }

  @override
  Future<void> markHistoryAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final workouts = await fetchWorkouts();
    final completedCount = workouts.where((w) => w.status == WorkoutStatus.completed).length;
    await prefs.setInt(_lastSeenHistoryCountKey, completedCount);
  }

  // -- helpers ---------------------------------------------------------------

  Future<void> _persistWorkouts(List<Workout> workouts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = workouts.map((w) => jsonEncode(w.toJson())).toList();
    await prefs.setStringList(_workoutsKey, encoded);
  }

  Workout _ensureId(Workout workout) {
    if (workout.id != null && workout.id!.isNotEmpty) {
      return workout;
    }
    return workout.copyWith(id: workout.effectiveId);
  }

  Workout _workoutFromJson(Map<String, dynamic> json) {
    // Parse exercises from 'exercises' or legacy 'sets' key
    final rawExercises = json['exercises'] as List<dynamic>? ?? 
                         json['sets'] as List<dynamic>? ?? [];
    final exercises = rawExercises
        .whereType<Map<String, dynamic>>()
        .map((e) => Exercise(
              exerciseName: (e['exerciseName'] ?? '').toString(),
              sets: int.tryParse((e['sets'] ?? '1').toString()) ?? 1,
              reps: int.tryParse((e['reps'] ?? '0').toString()) ?? 0,
              weight: double.tryParse((e['weight'] ?? '0').toString()) ?? 0,
              rpe: e['rpe'] != null
                  ? double.tryParse(e['rpe'].toString())
                  : null,
              notes: (e['notes'] ?? '').toString(),
              type: parseExerciseType(e['type']?.toString()),
              durationMinutes: e['durationMinutes'] != null
                  ? int.tryParse(e['durationMinutes'].toString())
                  : null,
              completed: e['completed'] != null 
                  ? List<bool>.from(e['completed'] as List)
                  : null,
            ))
        .toList();

    // Parse status with backward compatibility
    WorkoutStatus status;
    final rawStatus = json['status']?.toString();
    if (rawStatus == 'active') {
      status = WorkoutStatus.active;
    } else if (rawStatus == 'plan') {
      status = WorkoutStatus.plan;
    } else {
      // Default to completed for legacy data without status
      status = WorkoutStatus.completed;
    }

    return Workout(
      id: json['id']?.toString(),
      name: (json['name'] ?? 'Workout').toString(),
      summary: json['summary']?.toString(),
      aiComment: json['aiComment']?.toString(),
      date: DateTime.tryParse((json['date'] ?? '').toString()) ??
          DateTime.now(),
      status: status,
      exercises: exercises,
      durationMinutes: json['durationMinutes'] != null
          ? int.tryParse(json['durationMinutes'].toString())
          : null,
    );
  }

  @override
  Future<List<DashboardCardConfig>> fetchDashboardLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_dashboardLayoutKey);
    if (raw == null || raw.isEmpty) {
      return DashboardCardConfig.defaultLayout();
    }
    try {
      final saved = raw
          .map((e) => DashboardCardConfig.fromJson(
              jsonDecode(e) as Map<String, dynamic>))
          .toList();
      return DashboardCardConfig.mergeWithDefaults(saved);
    } catch (_) {
      return DashboardCardConfig.defaultLayout();
    }
  }

  @override
  Future<void> saveDashboardLayout(List<DashboardCardConfig> layout) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        layout.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_dashboardLayoutKey, encoded);
  }
}
