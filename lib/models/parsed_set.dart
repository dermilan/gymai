import 'set_log.dart';

class ParsedSet {
  final String exerciseName;
  final int sets;
  final int reps;
  final double weight;
  final String notes;
  final ExerciseType type;
  final int durationMinutes;

  const ParsedSet({
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.notes,
    required this.type,
    required this.durationMinutes,
  });

  factory ParsedSet.fromJson(Map<String, dynamic> json) {
    return ParsedSet(
      exerciseName: (json['exerciseName'] ?? '').toString(),
      sets: int.tryParse((json['sets'] ?? '1').toString()) ?? 1,
      reps: int.tryParse((json['reps'] ?? '0').toString()) ?? 0,
      weight: double.tryParse((json['weight'] ?? '0').toString()) ?? 0,
      notes: (json['notes'] ?? '').toString(),
      type: parseExerciseType(json['type']?.toString()),
      durationMinutes:
          int.tryParse((json['durationMinutes'] ?? '0').toString()) ?? 0,
    );
  }
}
