enum ExerciseType {
  strength,
  cardio,
}

ExerciseType parseExerciseType(String? raw) {
  switch (raw?.toLowerCase().trim()) {
    case 'cardio':
      return ExerciseType.cardio;
    case 'strength':
    default:
      return ExerciseType.strength;
  }
}

String exerciseTypeLabel(ExerciseType type) {
  return type == ExerciseType.cardio ? 'Cardio' : 'Strength';
}

class SetLog {
  final String exerciseName;
  final int reps;
  final double weight;
  final double? rpe;
  final String notes;
  final ExerciseType type;
  final int? durationMinutes;

  const SetLog({
    required this.exerciseName,
    required this.reps,
    required this.weight,
    this.rpe,
    this.notes = '',
    this.type = ExerciseType.strength,
    this.durationMinutes,
  });

  double get volume => reps * weight;

  factory SetLog.fromJson(Map<String, dynamic> json) {
    return SetLog(
      exerciseName: json['exerciseName'] as String,
      reps: json['reps'] as int,
      weight: (json['weight'] as num).toDouble(),
      rpe: (json['rpe'] as num?)?.toDouble(),
      notes: json['notes'] as String? ?? '',
      type: ExerciseType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ExerciseType.strength,
      ),
      durationMinutes: json['durationMinutes'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'reps': reps,
        'weight': weight,
        'rpe': rpe,
        'notes': notes,
      'type': type.name,
      'durationMinutes': durationMinutes,
      };
}
