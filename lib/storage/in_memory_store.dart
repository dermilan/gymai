import '../models/set_log.dart';
import '../models/user_prefs.dart';
import '../models/workout_log.dart';
import '../models/active_session.dart';
import 'local_store.dart';

class InMemoryStore implements LocalStore {
  ActiveSession? _activeSession;
  final List<WorkoutLog> _workouts = [
    WorkoutLog(
      id: 'sample-push',
      name: 'Push Day',
      date: DateTime.now().subtract(const Duration(days: 2)),
      sets: const [
        SetLog(exerciseName: 'Bench Press', reps: 5, weight: 185),
        SetLog(exerciseName: 'Overhead Press', reps: 8, weight: 95),
      ],
      durationMinutes: 55,
    ),
    WorkoutLog(
      id: 'sample-pull',
      name: 'Pull Day',
      date: DateTime.now().subtract(const Duration(days: 1)),
      sets: const [
        SetLog(exerciseName: 'Deadlift', reps: 3, weight: 315),
        SetLog(exerciseName: 'Row', reps: 10, weight: 135),
      ],
      durationMinutes: 60,
    ),
  ];

  UserPrefs _prefs = UserPrefs.empty();

  @override
  Future<List<WorkoutLog>> fetchWorkouts() async {
    for (var i = 0; i < _workouts.length; i += 1) {
      final entry = _workouts[i];
      if (entry.id == null || entry.id!.isEmpty) {
        _workouts[i] = _withId(entry, entry.effectiveId);
      }
    }
    return List.unmodifiable(_workouts);
  }

  @override
  Future<void> saveWorkout(WorkoutLog log) async {
    _workouts.insert(0, _ensureId(log));
  }

  @override
  Future<void> updateWorkout(WorkoutLog log) async {
    final index = _workouts.indexWhere(
      (entry) => entry.effectiveId == log.effectiveId,
    );
    if (index == -1) {
      return;
    }
    final existing = _workouts[index];
    final resolvedId = (log.id != null && log.id!.isNotEmpty)
        ? log.id!
        : (existing.id ?? log.effectiveId);
    _workouts[index] = _withId(log, resolvedId);
  }

  @override
  Future<void> deleteWorkout(String id) async {
    _workouts.removeWhere((entry) => entry.effectiveId == id);
  }

  @override
  Future<UserPrefs> fetchPrefs() async {
    return _prefs;
  }

  @override
  Future<void> savePrefs(UserPrefs prefs) async {
    _prefs = prefs;
  }

  @override
  Future<ActiveSession?> fetchActiveSession() async => _activeSession;

  @override
  Future<void> saveActiveSession(ActiveSession session) async {
    _activeSession = session;
  }

  @override
  Future<void> clearActiveSession() async {
    _activeSession = null;
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
}
