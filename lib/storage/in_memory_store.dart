import '../models/dashboard_card_config.dart';
import '../models/user_prefs.dart';
import '../models/workout.dart';
import 'local_store.dart';

class InMemoryStore implements LocalStore {
  Workout? _activeSession;
  final List<Workout> _workouts = [
    Workout(
      id: 'sample-push',
      name: 'Push Day',
      date: DateTime.now().subtract(const Duration(days: 2)),
      status: WorkoutStatus.completed,
      exercises: const [
        Exercise(exerciseName: 'Bench Press', sets: 1, reps: 5, weight: 185),
        Exercise(exerciseName: 'Overhead Press', sets: 1, reps: 8, weight: 95),
      ],
      durationMinutes: 55,
    ),
    Workout(
      id: 'sample-pull',
      name: 'Pull Day',
      date: DateTime.now().subtract(const Duration(days: 1)),
      status: WorkoutStatus.completed,
      exercises: const [
        Exercise(exerciseName: 'Deadlift', sets: 1, reps: 3, weight: 315),
        Exercise(exerciseName: 'Row', sets: 1, reps: 10, weight: 135),
      ],
      durationMinutes: 60,
    ),
  ];

  UserPrefs _prefs = UserPrefs.empty();

  @override
  Future<List<Workout>> fetchWorkouts() async {
    for (var i = 0; i < _workouts.length; i += 1) {
      final entry = _workouts[i];
      if (entry.id == null || entry.id!.isEmpty) {
        _workouts[i] = entry.copyWith(id: entry.effectiveId);
      }
    }
    return List.unmodifiable(_workouts);
  }

  @override
  Future<void> saveWorkout(Workout workout) async {
    _workouts.insert(0, _ensureId(workout));
  }

  @override
  Future<void> updateWorkout(Workout workout) async {
    final index = _workouts.indexWhere(
      (entry) => entry.effectiveId == workout.effectiveId,
    );
    if (index == -1) {
      return;
    }
    final existing = _workouts[index];
    final resolvedId = (workout.id != null && workout.id!.isNotEmpty)
        ? workout.id!
        : (existing.id ?? workout.effectiveId);
    _workouts[index] = workout.copyWith(id: resolvedId);
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
  Future<Workout?> fetchActiveSession() async => _activeSession;

  @override
  Future<void> saveActiveSession(Workout session) async {
    _activeSession = session;
  }

  @override
  Future<void> clearActiveSession() async {
    _activeSession = null;
  }

  int _lastSeenHistoryCount = 0;

  @override
  Future<int> getUnseenHistoryCount() async {
    final completedCount = _workouts.where((w) => w.status == WorkoutStatus.completed).length;
    return (completedCount - _lastSeenHistoryCount).clamp(0, completedCount);
  }

  @override
  Future<void> markHistoryAsSeen() async {
    _lastSeenHistoryCount = _workouts.where((w) => w.status == WorkoutStatus.completed).length;
  }

  Workout _ensureId(Workout workout) {
    if (workout.id != null && workout.id!.isNotEmpty) {
      return workout;
    }
    return workout.copyWith(id: workout.effectiveId);
  }

  List<DashboardCardConfig> _dashboardLayout = DashboardCardConfig.defaultLayout();

  @override
  Future<List<DashboardCardConfig>> fetchDashboardLayout() async =>
      List.from(_dashboardLayout);

  @override
  Future<void> saveDashboardLayout(List<DashboardCardConfig> layout) async {
    _dashboardLayout = List.from(layout);
  }
}
