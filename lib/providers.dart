import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/dashboard_card_config.dart';
import 'models/user_prefs.dart';
import 'models/workout.dart';
import 'services/ai_proxy_client.dart';
import 'storage/local_store.dart';
import 'storage/database_store.dart';
import 'storage/shared_prefs_store.dart';

// =============================================================================
// Core Services
// =============================================================================

/// Local storage provider (platform-aware: SQLite on native, SharedPrefs on web)
final storeProvider = Provider<LocalStore>((ref) {
  return kIsWeb ? SharedPrefsStore() : DatabaseStore();
});

/// AI proxy client for Cloud Functions
final aiProxyProvider = Provider<AiProxyClient>((ref) {
  return AiProxyClient();
});

// =============================================================================
// Data Providers
// =============================================================================

/// All workouts from local storage
final workoutsProvider = FutureProvider<List<Workout>>((ref) async {
  final store = ref.watch(storeProvider);
  return store.fetchWorkouts();
});

/// User preferences
final prefsProvider = FutureProvider<UserPrefs>((ref) async {
  final store = ref.watch(storeProvider);
  return store.fetchPrefs();
});

/// Active workout session (null if none)
final activeSessionProvider = FutureProvider<Workout?>((ref) async {
  final store = ref.watch(storeProvider);
  return store.fetchActiveSession();
});

/// Dashboard card layout configuration
final dashboardLayoutProvider = FutureProvider<List<DashboardCardConfig>>((ref) async {
  final store = ref.watch(storeProvider);
  return store.fetchDashboardLayout();
});

/// Unseen history count (for badge)
final unseenHistoryCountProvider = FutureProvider<int>((ref) async {
  final store = ref.watch(storeProvider);
  return store.getUnseenHistoryCount();
});

// =============================================================================
// State Notifiers for UI Events
// =============================================================================

/// Confetti trigger - increment to play celebration animation
final confettiTriggerProvider = StateProvider<int>((ref) => 0);
