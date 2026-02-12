import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/parsed_workout.dart';
import '../models/user_prefs.dart';
import '../models/workout_log.dart';
import 'prompt_templates.dart';

class OpenRouterClient {
  final String apiKey;
  final String model;
  final String baseUrl;
  final String? referer;
  final String? title;

  const OpenRouterClient({
    required this.apiKey,
    required this.model,
    this.baseUrl = 'https://openrouter.ai/api/v1/chat/completions',
    this.referer,
    this.title,
  });

  bool get _isConfigured {
    return apiKey != 'YOUR_OPENROUTER_API_KEY';
  }

  Future<String> generateWorkoutPlan({
    required UserPrefs prefs,
    required List<WorkoutLog> recentWorkouts,
  }) async {
    final prompt = buildWorkoutPlanPrompt(prefs, recentWorkouts);

    if (!_isConfigured) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return 'Example plan based on prompt:\n\n$prompt\n\n- Squat 4x6\n- Bench 4x8\n- Row 3x10\n- Lunges 3x12\n- Plank 3x45s';
    }

    final content = await _chatCompletion(prompt);
    return content.trim();
  }

  Future<ParsedWorkout> parseWorkoutNotes(String notes) async {
    if (!_isConfigured) {
      throw StateError('OpenRouter is not configured yet.');
    }

    final prompt = buildParseWorkoutNotesPrompt(notes);
    final content = await _chatCompletion(prompt);
    final jsonText = _extractJsonObject(content);
    final data = jsonDecode(jsonText) as Map<String, dynamic>;
    return ParsedWorkout.fromJson(data);
  }

  Future<String> _chatCompletion(String prompt) async {
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
