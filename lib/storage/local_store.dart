import '../models/dashboard_card_config.dart';
import '../models/user_prefs.dart';
import '../models/workout.dart';

abstract class LocalStore {
  Future<List<Workout>> fetchWorkouts();
  Future<void> saveWorkout(Workout workout);
  Future<void> updateWorkout(Workout workout);
  Future<void> deleteWorkout(String id);
  Future<UserPrefs> fetchPrefs();
  Future<void> savePrefs(UserPrefs prefs);

  Future<Workout?> fetchActiveSession();
  Future<void> saveActiveSession(Workout session);
  Future<void> clearActiveSession();

  /// Returns the number of unseen completed workouts in history.
  Future<int> getUnseenHistoryCount();

  /// Marks all current history as seen (resets badge).
  Future<void> markHistoryAsSeen();

  /// Fetch the user's dashboard card layout (order + visibility).
  Future<List<DashboardCardConfig>> fetchDashboardLayout();

  /// Save the user's dashboard card layout.
  Future<void> saveDashboardLayout(List<DashboardCardConfig> layout);
}
