// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ExerciseImpl _$$ExerciseImplFromJson(Map<String, dynamic> json) =>
    _$ExerciseImpl(
      exerciseName: json['exerciseName'] as String,
      sets: (json['sets'] as num?)?.toInt() ?? 1,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      type: $enumDecodeNullable(_$ExerciseTypeEnumMap, json['type']) ??
          ExerciseType.strength,
      notes: json['notes'] as String? ?? '',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      completed:
          (json['completed'] as List<dynamic>?)?.map((e) => e as bool).toList(),
      rpe: (json['rpe'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$ExerciseImplToJson(_$ExerciseImpl instance) =>
    <String, dynamic>{
      'exerciseName': instance.exerciseName,
      'sets': instance.sets,
      'reps': instance.reps,
      'weight': instance.weight,
      'type': _$ExerciseTypeEnumMap[instance.type]!,
      'notes': instance.notes,
      'durationMinutes': instance.durationMinutes,
      'completed': instance.completed,
      'rpe': instance.rpe,
    };

const _$ExerciseTypeEnumMap = {
  ExerciseType.strength: 'strength',
  ExerciseType.cardio: 'cardio',
  ExerciseType.flexibility: 'flexibility',
};

_$WorkoutImpl _$$WorkoutImplFromJson(Map<String, dynamic> json) =>
    _$WorkoutImpl(
      id: json['id'] as String?,
      name: json['name'] as String,
      summary: json['summary'] as String?,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      date: DateTime.parse(json['date'] as String),
      status: $enumDecodeNullable(_$WorkoutStatusEnumMap, json['status']) ??
          WorkoutStatus.plan,
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
      aiComment: json['aiComment'] as String?,
    );

Map<String, dynamic> _$$WorkoutImplToJson(_$WorkoutImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'summary': instance.summary,
      'durationMinutes': instance.durationMinutes,
      'date': instance.date.toIso8601String(),
      'status': _$WorkoutStatusEnumMap[instance.status]!,
      'exercises': instance.exercises,
      'aiComment': instance.aiComment,
    };

const _$WorkoutStatusEnumMap = {
  WorkoutStatus.plan: 'plan',
  WorkoutStatus.active: 'active',
  WorkoutStatus.completed: 'completed',
};
