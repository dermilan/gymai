/// Unified workout model for all lifecycle stages:
/// - plan: AI-generated workout template
/// - active: In-progress workout being tracked
/// - completed: Saved workout history
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout.freezed.dart';
part 'workout.g.dart';

enum WorkoutStatus { plan, active, completed }

enum ExerciseType { strength, cardio, flexibility }

ExerciseType parseExerciseType(String? raw) {
  switch (raw?.toLowerCase().trim()) {
    case 'cardio':
      return ExerciseType.cardio;
    case 'flexibility':
      return ExerciseType.flexibility;
    case 'strength':
    default:
      return ExerciseType.strength;
  }
}

String exerciseTypeLabel(ExerciseType type) {
  switch (type) {
    case ExerciseType.cardio:
      return 'Cardio';
    case ExerciseType.flexibility:
      return 'Flexibility';
    case ExerciseType.strength:
      return 'Strength';
  }
}


@freezed
class Exercise with _$Exercise {
  const Exercise._();

  const factory Exercise({
    required String exerciseName,
    @Default(1) int sets,
    @Default(0) int reps,
    @Default(0) double weight,
    @Default(ExerciseType.strength) ExerciseType type,
    @Default('') String notes,
    int? durationMinutes,
    List<bool>? completed, // Tracks which sets are done (for active/completed)
    double? rpe, // Rate of Perceived Exertion (for completed)
  }) = _Exercise;

  double get volume => reps * weight;

  /// Toggle completion status of a specific set
  Exercise toggleSet(int index) {
    if (completed == null) return this;
    final newList = List<bool>.from(completed!);
    if (index >= 0 && index < newList.length) {
      newList[index] = !newList[index];
    }
    return copyWith(completed: newList);
  }

  factory Exercise.fromJson(Map<String, dynamic> json) =>
      _$ExerciseFromJson(json);

  @override
  Map<String, dynamic> toJson();
}

@freezed
class Workout with _$Workout {
  const Workout._();

  const factory Workout({
    String? id,
    required String name,
    String? summary,
    int? durationMinutes,
    required DateTime date,
    @Default(WorkoutStatus.plan) WorkoutStatus status,
    required List<Exercise> exercises,
    String? aiComment, // AI feedback for completed workouts
  }) = _Workout;

  /// Unique identifier - uses id if set, otherwise generates from date+name
  String get effectiveId =>
      (id != null && id!.isNotEmpty)
          ? id!
          : '${date.microsecondsSinceEpoch}-$name';

  /// Total workout volume (sum of all exercise volumes)
  double get totalVolume =>
      exercises.fold(0, (total, ex) => total + ex.volume);

  /// Convert plan to active session with tracking state
  Workout toActive() {
    return copyWith(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      status: WorkoutStatus.active,
      exercises: exercises
          .map((ex) => ex.copyWith(
                completed: List.filled(ex.sets, false),
              ))
          .toList(),
    );
  }

  /// Convert active session to completed workout
  Workout toCompleted({String? aiComment}) {
    return copyWith(
      status: WorkoutStatus.completed,
      aiComment: aiComment,
    );
  }

  factory Workout.fromJson(Map<String, dynamic> json) =>
      _$WorkoutFromJson(_preprocessWorkoutJson(json));

  @override
  Map<String, dynamic> toJson();

  static Map<String, dynamic> _preprocessWorkoutJson(Map<String, dynamic> json) {
    // Handle 'sessionDate' legacy key
    if (json['sessionDate'] != null && json['date'] == null) {
      json['date'] = json['sessionDate'];
    }

    // Handle 'sets' legacy key for exercises
    if (json['sets'] != null && json['exercises'] == null) {
      json['exercises'] = json['sets'];
    }

    // Default name if missing
    if (json['name'] == null) {
      json['name'] = 'Workout';
    }

    // Handle date parsing safely
    if (json['date'] == null ||
        (json['date'] is String && (json['date'] as String).isEmpty)) {
      json['date'] = DateTime.now().toIso8601String();
    }

    return json;
  }
}

