import 'set_log.dart';

class ActiveSession {
  final String id;
  final String name;
  final String? summary;
  final DateTime date;
  final List<ActiveExercise> exercises;

  const ActiveSession({
    required this.id,
    required this.name,
    this.summary,
    required this.date,
    required this.exercises,
  });

  factory ActiveSession.fromJson(Map<String, dynamic> json) {
    return ActiveSession(
      id: json['id'] as String,
      name: json['name'] as String,
      summary: json['summary'] as String?,
      date: DateTime.parse(json['date'] as String),
      exercises: (json['exercises'] as List)
          .map((e) => ActiveExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'summary': summary,
        'date': date.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  ActiveSession copyWith({List<ActiveExercise>? exercises}) {
    return ActiveSession(
      id: id,
      name: name,
      summary: summary,
      date: date,
      exercises: exercises ?? this.exercises,
    );
  }
}

class ActiveExercise {
  final String exerciseName;
  final int sets;
  final int reps;
  final double weight;
  final List<bool> completed;
  final ExerciseType type;
  final int? durationMinutes;
  final String? notes;

  const ActiveExercise({
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.completed,
    this.type = ExerciseType.strength,
    this.durationMinutes,
    this.notes,
  });

  factory ActiveExercise.fromJson(Map<String, dynamic> json) {
    return ActiveExercise(
      exerciseName: json['exerciseName'] as String,
      sets: json['sets'] as int,
      reps: json['reps'] as int,
      weight: (json['weight'] as num).toDouble(),
      completed: List<bool>.from(json['completed'] as List),
      type: ExerciseType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ExerciseType.strength,
      ),
      durationMinutes: json['durationMinutes'] as int?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'sets': sets,
        'reps': reps,
        'weight': weight,
        'completed': completed,
        'type': type.name,
        'durationMinutes': durationMinutes,
        'notes': notes,
      };

  ActiveExercise toggleSet(int index) {
    final newList = List<bool>.from(completed);
    newList[index] = !newList[index];
    return ActiveExercise(
      exerciseName: exerciseName,
      sets: sets,
      reps: reps,
      weight: weight,
      completed: newList,
      type: type,
      durationMinutes: durationMinutes,
      notes: notes,
    );
  }
}
