import '../models/user_prefs.dart';
import '../models/workout_log.dart';

String buildWorkoutPlanPrompt(UserPrefs prefs, List<WorkoutLog> recentWorkouts) {
  final buffer = StringBuffer();
  buffer.writeln('You are a fitness coach.');
  buffer.writeln('Goal: ${prefs.goal}.');
  buffer.writeln('Days per week: ${prefs.daysPerWeek}.');
  buffer.writeln('Equipment: ${prefs.equipment}.');
  buffer.writeln('Injuries: ${prefs.injuries}.');
  buffer.writeln('Recent workouts:');

  for (final workout in recentWorkouts.take(3)) {
    buffer.writeln('- ${workout.name} on ${workout.date.toIso8601String()}');
    for (final set in workout.sets.take(6)) {
      buffer.writeln(
          '  ${set.exerciseName} (${set.type.name}): ${set.reps} reps @ ${set.weight}, ${set.durationMinutes ?? 0} min');
    }
  }

  buffer.writeln('Return a next workout with sets, reps, and brief rationale.');
  return buffer.toString();
}

String buildParseWorkoutNotesPrompt(String notes) {
  return [
    'You are a parser for gym workout notes.',
    'Return ONLY valid JSON as an object with fields: sessionDate, sets.',
    'sessionDate must be an ISO 8601 string or null if missing.',
    'sets must be an array of objects.',
    'Each set object must include: exerciseName, sets, reps, weight, notes, type, durationMinutes.',
    'type must be either "strength" or "cardio".',
    'durationMinutes must be an integer (0 if unknown).',
    'Use numbers for sets, reps, and weight.',
    'If notes are unclear, set notes to "Needs review".',
    'Text to parse:',
    notes,
  ].join('\n');
}
