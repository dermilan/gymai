import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../widgets/dashboard_cards/volume_trend_card.dart';

class DashboardStats {
  /// Calculate the difference in volume between this week and last week
  static (String, double, Color, IconData) calculateTrendStats(
      List<Workout> workouts, double thisWeekVol) {
    final now = DateTime.now();
    final startOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
    
    double lastWeekVol = 0;
    for (final w in workouts) {
      if (w.status != WorkoutStatus.completed) continue;
      if (w.date.isAfter(startOfLastWeek) && w.date.isBefore(startOfThisWeek)) {
        lastWeekVol += w.totalVolume;
      }
    }

    double diff = thisWeekVol - lastWeekVol;
    double trend = lastWeekVol == 0 ? 0 : (diff / lastWeekVol) * 100;
    
    if (lastWeekVol == 0 && thisWeekVol > 0) trend = 100;

    final trendIcon =
        diff >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    final trendColor = 
        diff >= 0 ? const Color(0xFF00BFA6) : const Color(0xFFFF5252);
    final trendLabel = '${diff >= 0 ? "+" : ""}${trend.toStringAsFixed(1)}%';
    
    return (trendLabel, trend, trendColor, trendIcon);
  }

  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    if (difference.inDays < 14) return '1 week ago';
    return '${(difference.inDays / 7).floor()} weeks ago';
  }

  /// Count consecutive weeks (ending with the current week) where the user
  /// completed at least [targetDays] workouts.
  static int calculateStreak(List<Workout> workouts, int targetDays) {
    if (workouts.isEmpty) return 0;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final currentWeekStart = todayStart.subtract(Duration(days: now.weekday - 1));

    int streak = 0;
    DateTime weekStart = currentWeekStart;
    
    // dynamically check backwards without arbitrary 52-week limit
    while (true) {
      final weekEnd = weekStart.add(const Duration(days: 7));
      final count = workouts
          .where((wk) =>
              wk.status == WorkoutStatus.completed &&
              wk.date.isAfter(weekStart) &&
              wk.date.isBefore(weekEnd))
          .length;

      if (count >= targetDays) {
        streak++;
        weekStart = weekStart.subtract(const Duration(days: 7));
      } else {
        break;
      }
    }
    return streak;
  }

  /// Finds specific exercises with max weight across all completed workouts.
  /// Returns top 3 by weight.
  static List<MapEntry<String, double>> getPersonalRecords(
      List<Workout> workouts) {
    final maxWeights = <String, double>{};

    for (final w in workouts) {
      if (w.status != WorkoutStatus.completed) continue;
      for (final ex in w.exercises) {
        if (ex.weight <= 0) continue;
        final currentMax = maxWeights[ex.exerciseName] ?? 0;
        if (ex.weight > currentMax) {
          maxWeights[ex.exerciseName] = ex.weight;
        }
      }
    }

    final sorted = maxWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).toList();
  }

  /// Returns a map of ExerciseType → count across all completed workouts.
  static Map<ExerciseType, int> getExerciseSplit(List<Workout> workouts) {
    final counts = <ExerciseType, int>{};
    for (final w in workouts) {
      if (w.status != WorkoutStatus.completed) continue;
      for (final ex in w.exercises) {
        counts[ex.type] = (counts[ex.type] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Return top-3 most frequently performed exercises.
  static List<MapEntry<String, int>> getFavoriteExercises(
      List<Workout> workouts) {
    final freq = <String, int>{};
    for (final w in workouts) {
      if (w.status != WorkoutStatus.completed) continue;
      for (final ex in w.exercises) {
        freq[ex.exerciseName] = (freq[ex.exerciseName] ?? 0) + 1;
      }
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).toList();
  }

  /// Days since the last completed workout (or -1 if no workouts).
  static int getDaysSinceLastWorkout(List<Workout> workouts) {
    final completed = workouts
        .where((w) => w.status == WorkoutStatus.completed)
        .toList();
    if (completed.isEmpty) return -1;
    completed.sort((a, b) => b.date.compareTo(a.date));
    return DateTime.now().difference(completed.first.date).inDays;
  }

  /// Return a chronological list of (date, totalTonnage) for completed workouts.
  /// Tonnage = Σ(sets × reps × weight) per workout.
  static List<VolumeDayPoint> getVolumeTrendData(List<Workout> workouts) {
    final completed = workouts
        .where((w) => w.status == WorkoutStatus.completed)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return completed.map((w) {
      final tonnage = w.exercises.fold<double>(
        0,
        (sum, ex) => sum + (ex.sets * ex.reps * ex.weight),
      );
      return VolumeDayPoint(date: w.date, volume: tonnage);
    }).toList();
  }
}
