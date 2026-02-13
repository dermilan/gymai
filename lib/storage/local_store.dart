import '../models/user_prefs.dart';
import '../models/workout_log.dart';
import '../models/active_session.dart';

abstract class LocalStore {
  Future<List<WorkoutLog>> fetchWorkouts();
  Future<void> saveWorkout(WorkoutLog log);
  Future<void> updateWorkout(WorkoutLog log);
  Future<void> deleteWorkout(String id);
  Future<UserPrefs> fetchPrefs();
  Future<void> savePrefs(UserPrefs prefs);

  Future<ActiveSession?> fetchActiveSession();
  Future<void> saveActiveSession(ActiveSession session);
  Future<void> clearActiveSession();
}
