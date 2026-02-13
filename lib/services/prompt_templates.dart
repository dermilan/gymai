import 'dart:convert';

import '../models/user_prefs.dart';
import '../models/workout_log.dart';

String _getPersonaPrompt(UserPrefs prefs) {
  final name = prefs.preferredName;
  switch (prefs.persona) {
    case 'Evidence-Based Scientist':
      return 'You are an Evidence-Based Fitness Scientist. Address the user as $name. Use clinical, technical language (e.g., hypertrophy, motor unit recruitment, systemic fatigue). Focus on data and physiological optimization. Your tone is formal and academic.';
    case 'Old-School Drill Sergeant':
      return 'You are a no-nonsense Old-School Drill Sergeant. Address the user as $name. Your tone is aggressive, demanding, and high-intensity. Use tough love and focus on discipline and grit. No excuses.';
    case 'Supportive Zen Coach':
      return 'You are a Supportive Zen Fitness Coach. Address the user as $name. Your tone is calm, encouraging, and focused on mindfulness, longevity, and listening to the body. Emphasize recovery and consistency.';
    case 'Data-Driven Strategist':
      return 'You are a Data-Driven Fitness Strategist. Address the user as $name. Your tone is cold, analytical, and strictly objective. Focus on efficiency, trend lines, and optimal throughput.';
    case 'Gym Bro':
    default:
      return 'You are a high-energy "Gym Bro." Address the user as $name. Use gym bro slang. Your tone is extremely casual and hyped.';
  }
}

String buildWorkoutPlanPrompt(UserPrefs prefs, List<WorkoutLog> recentWorkouts) {
  final buffer = StringBuffer();
  buffer.writeln(_getPersonaPrompt(prefs));
  buffer.writeln('Goal: ${prefs.goal}.');
  buffer.writeln('Days per week: ${prefs.daysPerWeek}.');
  buffer.writeln('Session duration (minutes): ${prefs.sessionDurationMinutes}.');
  buffer.writeln('Include warm-up: ${prefs.includeWarmUp ? "yes" : "no"}.');
  buffer.writeln('Include cool down: ${prefs.includeCoolDown ? "yes" : "no"}.');
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

  buffer.writeln('\nReturn a next workout as a JSON object.');
  buffer.writeln('Include fields: name, summary, durationMinutes, exercises.');
  buffer.writeln('Each exercise must have: exerciseName, sets (int), reps (int), weight (num), type ("strength" or "cardio"), durationMinutes (int), notes.');
  buffer.writeln('Return ONLY the raw JSON object.');
  return buffer.toString();
}

String buildPlanRefinementPrompt(
  UserPrefs prefs,
  Map<String, dynamic> planJson,
  String feedback,
) {
  final buffer = StringBuffer();
  buffer.writeln(_getPersonaPrompt(prefs));
  buffer.writeln('Goal: ${prefs.goal}.');
  buffer.writeln('Days per week: ${prefs.daysPerWeek}.');
  buffer.writeln('Session duration (minutes): ${prefs.sessionDurationMinutes}.');
  buffer.writeln('Include warm-up: ${prefs.includeWarmUp ? "yes" : "no"}.');
  buffer.writeln('Include cool down: ${prefs.includeCoolDown ? "yes" : "no"}.');
  buffer.writeln('Equipment: ${prefs.equipment}.');
  buffer.writeln('Injuries: ${prefs.injuries}.');
  buffer.writeln('Current plan JSON:');
  buffer.writeln(jsonEncode(planJson));
  buffer.writeln('User feedback to refine the plan:');
  buffer.writeln(feedback);
  buffer.writeln('\nReturn an updated workout as a JSON object.');
  buffer.writeln('Include fields: name, summary, durationMinutes, exercises.');
  buffer.writeln('Each exercise must have: exerciseName, sets (int), reps (int), weight (num), type ("strength" or "cardio"), durationMinutes (int), notes.');
  buffer.writeln('Return ONLY the raw JSON object.');
  return buffer.toString();
}

String buildSessionCommentPrompt(
  UserPrefs prefs,
  WorkoutLog current,
  WorkoutLog? previous,
) {
  final buffer = StringBuffer();
  buffer.writeln(_getPersonaPrompt(prefs));
  buffer.writeln('Write a short comment about the completed session.');
  buffer.writeln('Keep it to 1-2 sentences, in persona voice.');
  buffer.writeln('Mention any notable comparison with the previous session if relevant.');
  buffer.writeln('Current session:');
  buffer.writeln('Name: ${current.name}.');
  if (current.summary != null && current.summary!.isNotEmpty) {
    buffer.writeln('Summary: ${current.summary}.');
  }
  buffer.writeln('Duration: ${current.durationMinutes ?? 0} minutes.');
  buffer.writeln('Sets:');
  for (final set in current.sets.take(10)) {
    buffer.writeln(
        '- ${set.exerciseName}: ${set.reps} reps @ ${set.weight} (${set.type.name})');
  }
  if (previous != null) {
    buffer.writeln('Previous session:');
    buffer.writeln('Name: ${previous.name}.');
    if (previous.summary != null && previous.summary!.isNotEmpty) {
      buffer.writeln('Summary: ${previous.summary}.');
    }
    buffer.writeln('Duration: ${previous.durationMinutes ?? 0} minutes.');
    buffer.writeln('Sets:');
    for (final set in previous.sets.take(6)) {
      buffer.writeln(
          '- ${set.exerciseName}: ${set.reps} reps @ ${set.weight} (${set.type.name})');
    }
  } else {
    buffer.writeln('Previous session: none.');
  }
  buffer.writeln('Return ONLY the comment text.');
  return buffer.toString();
}

String buildParseWorkoutNotesPrompt(UserPrefs prefs, String notes) {
  return [
    _getPersonaPrompt(prefs),
    'You are also a parser for gym workout notes.',
    'Return ONLY valid JSON as an object with fields: sessionDate, name, summary, sets.',
    'sessionDate must be an ISO 8601 string or null if missing.',
    'name must be a short, punchy title written in your specific persona style.',
    'summary must be a one-sentence summary of the focus, written in your specific persona style.',
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
