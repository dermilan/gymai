import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/parsed_workout.dart';
import '../models/user_prefs.dart';
import '../models/workout_log.dart';
import 'prompt_templates.dart';
import 'rate_limiter.dart';

class OpenRouterClient {
  final String apiKey;
  final String model;
  final String baseUrl;
  final String? referer;
  final String? title;
  final RateLimiter? rateLimiter;

  static const int _maxPromptChars = 8000;
  static const int _maxNotesChars = 4000;
  static const int _maxFeedbackChars = 800;

  const OpenRouterClient({
    required this.apiKey,
    required this.model,
    this.baseUrl = 'https://openrouter.ai/api/v1/chat/completions',
    this.referer,
    this.title,
    this.rateLimiter,
  });

  bool get _isConfigured {
    return apiKey != 'YOUR_OPENROUTER_API_KEY';
  }

  Future<String> generateWorkoutPlan({
    required UserPrefs prefs,
    required List<WorkoutLog> recentWorkouts,
  }) async {
    final prompt = buildWorkoutPlanPrompt(prefs, recentWorkouts);
    _ensurePromptLength(prompt);

    if (!_isConfigured) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      // Mocked JSON-ish response for non-configured users
      return jsonEncode({
        'name': 'Sample Workout',
        'summary': 'A solid full body session.',
        'durationMinutes': 55,
        'exercises': [
          {'exerciseName': 'Squat', 'sets': 4, 'reps': 6, 'weight': 60, 'type': 'strength'},
          {'exerciseName': 'Bench', 'sets': 4, 'reps': 8, 'weight': 40, 'type': 'strength'},
        ],
      });
    }

    final content = await _chatCompletion(prompt);
    return content.trim();
  }

  Future<String> refineWorkoutPlan({
    required UserPrefs prefs,
    required Map<String, dynamic> planJson,
    required String feedback,
  }) async {
    _ensureInputLength('Feedback', feedback, _maxFeedbackChars);
    final prompt = buildPlanRefinementPrompt(prefs, planJson, feedback);
    _ensurePromptLength(prompt);

    if (!_isConfigured) {
      final updated = Map<String, dynamic>.from(planJson);
      final existingSummary = updated['summary']?.toString() ?? '';
      updated['summary'] = existingSummary.isEmpty
          ? 'Refined plan based on your feedback.'
          : '$existingSummary (Refined)';
      return jsonEncode(updated);
    }

    final content = await _chatCompletion(prompt);
    return content.trim();
  }

  Future<ParsedWorkout> parseWorkoutNotes(UserPrefs prefs, String notes) async {
    if (!_isConfigured) {
      throw StateError('OpenRouter is not configured yet.');
    }

    _ensureInputLength('Notes', notes, _maxNotesChars);

    final prompt = buildParseWorkoutNotesPrompt(prefs, notes);
    final content = await _chatCompletion(prompt);
    final jsonText = _extractJsonObject(content);
    final data = jsonDecode(jsonText) as Map<String, dynamic>;
    return ParsedWorkout.fromJson(data);
  }

  Future<String> generateSessionComment({
    required UserPrefs prefs,
    required WorkoutLog current,
    WorkoutLog? previous,
  }) async {
    final prompt = buildSessionCommentPrompt(prefs, current, previous);
    _ensurePromptLength(prompt);

    if (!_isConfigured) {
      return '';
    }

    final content = await _chatCompletion(prompt);
    return content.trim();
  }

  Future<String> _chatCompletion(String prompt) async {
    rateLimiter?.check();
    final uri = Uri.parse(baseUrl);

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    if (referer != null && referer!.isNotEmpty) {
      headers['HTTP-Referer'] = referer!;
    }

    if (title != null && title!.isNotEmpty) {
      headers['X-Title'] = title!;
    }

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': 'You respond with plain text only.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.2,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'OpenRouter error: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = (data['choices'] as List<dynamic>?) ?? [];
    if (choices.isEmpty) {
      throw StateError('OpenRouter returned no choices.');
    }

    final message = choices.first as Map<String, dynamic>;
    final content = (message['message'] as Map<String, dynamic>?)?['content'];
    return content?.toString() ?? '';
  }

  void _ensurePromptLength(String prompt) {
    if (prompt.length > _maxPromptChars) {
      throw StateError('Prompt too long. Reduce input size and try again.');
    }
  }

  void _ensureInputLength(String label, String value, int maxChars) {
    if (value.trim().isEmpty) {
      throw StateError('$label is empty.');
    }
    if (value.length > maxChars) {
      throw StateError('$label too long. Max $maxChars chars.');
    }
  }

  String _extractJsonObject(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw StateError('Could not find JSON object in AI response.');
    }

    return trimmed.substring(start, end + 1);
  }
}
