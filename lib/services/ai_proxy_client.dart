import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/workout.dart';
import '../models/user_prefs.dart';

/// Client that calls Cloud Functions for AI features with usage limits
class AiProxyClient {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<String> generateWorkoutPlan({
    required UserPrefs prefs,
    required List<Workout> recentWorkouts,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    try {
      final callable = _functions.httpsCallable('generateWorkoutPlan');
      final result = await callable.call({
        'prefs': {
          'goal': prefs.goal,
          'daysPerWeek': prefs.daysPerWeek,
          'equipment': prefs.equipment,
          'injuries': prefs.injuries,
          'sessionDurationMinutes': prefs.sessionDurationMinutes,
          'includeWarmUp': prefs.includeWarmUp,
          'includeCoolDown': prefs.includeCoolDown,
          'persona': prefs.persona,
          'preferredName': prefs.preferredName,
        },
        'recentWorkouts': recentWorkouts.map((w) => {
          'date': w.date.toIso8601String(),
          'name': w.name,
          'exercises': w.exercises.map((e) => {
            'exerciseName': e.exerciseName,
            'reps': e.reps,
            'weight': e.weight,
            'notes': e.notes,
          }).toList(),
        }).toList(),
      });

      return result.data['plan'] as String;
    } catch (e) {
      debugPrint('generateWorkoutPlan error: $e');
      rethrow;
    }
  }

  Future<String> refineWorkoutPlan({
    required UserPrefs prefs,
    required List<Workout> recentWorkouts,
    required Map<String, dynamic> planJson,
    required String feedback,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    try {
      final callable = _functions.httpsCallable('generateWorkoutPlan');
      final result = await callable.call({
        'prefs': {
          'goal': prefs.goal,
          'daysPerWeek': prefs.daysPerWeek,
          'equipment': prefs.equipment,
          'injuries': prefs.injuries,
          'sessionDurationMinutes': prefs.sessionDurationMinutes,
          'includeWarmUp': prefs.includeWarmUp,
          'includeCoolDown': prefs.includeCoolDown,
          'persona': prefs.persona,
          'preferredName': prefs.preferredName,
        },
        'recentWorkouts': recentWorkouts.map((w) => {
          'date': w.date.toIso8601String(),
          'name': w.name,
          'exercises': w.exercises.map((e) => {
            'exerciseName': e.exerciseName,
            'reps': e.reps,
            'weight': e.weight,
            'notes': e.notes,
          }).toList(),
        }).toList(),
        'currentPlan': planJson,
        'feedback': feedback,
      });

      return result.data['plan'] as String;
    } catch (e) {
      debugPrint('refineWorkoutPlan error: $e');
      rethrow;
    }
  }

  Future<Workout> parseWorkoutNotes(UserPrefs prefs, String notes) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    try {
      final callable = _functions.httpsCallable('parseWorkoutNotes');
      final result = await callable.call({
        'prefs': {
          'persona': prefs.persona,
          'preferredName': prefs.preferredName,
        },
        'notes': notes,
      });

      final workoutJson = result.data['workout'] as Map<String, dynamic>;
      return Workout.fromJson(workoutJson);
    } catch (e) {
      debugPrint('parseWorkoutNotes error: $e');
      rethrow;
    }
  }

  Future<String> generateSessionComment({
    required UserPrefs prefs,
    required Workout current,
    Workout? previous,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    try {
      final callable = _functions.httpsCallable('generateSessionComment');
      final result = await callable.call({
        'prefs': {
          'persona': prefs.persona,
          'preferredName': prefs.preferredName,
        },
        'current': {
          'date': current.date.toIso8601String(),
          'name': current.name,
          'exercises': current.exercises.map((e) => {
            'exerciseName': e.exerciseName,
            'reps': e.reps,
            'weight': e.weight,
            'notes': e.notes,
          }).toList(),
        },
        'previous': previous != null ? {
          'date': previous.date.toIso8601String(),
          'name': previous.name,
          'exercises': previous.exercises.map((e) => {
            'exerciseName': e.exerciseName,
            'reps': e.reps,
            'weight': e.weight,
            'notes': e.notes,
          }).toList(),
        } : null,
      });

      return result.data['comment'] as String;
    } catch (e) {
      debugPrint('generateSessionComment error: $e');
      rethrow;
    }
  }

  Future<int> getRemainingRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return 0;

    final data = doc.data()!;
    final tier = data['tier'] as String? ?? 'free';
    final used = data['aiRequestsThisMonth'] as int? ?? 0;

    final limits = {'free': 15, 'plus': 150, 'pro': -1};
    final limit = limits[tier] ?? 15;

    if (limit == -1) return -1; // Unlimited
    return (limit - used).clamp(0, limit);
  }
}
