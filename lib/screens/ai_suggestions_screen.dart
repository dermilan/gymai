import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_prefs.dart';
import '../models/workout.dart';
import '../providers.dart';
import '../utils/weight_utils.dart';
import 'log_workout_screen.dart';

class AiSuggestionsScreen extends ConsumerStatefulWidget {
  const AiSuggestionsScreen({super.key});

  @override
  ConsumerState<AiSuggestionsScreen> createState() => _AiSuggestionsScreenState();
}

class _AiSuggestionsScreenState extends ConsumerState<AiSuggestionsScreen> {
  final TextEditingController _replyController = TextEditingController();
  bool _loading = false;
  bool _refining = false;
  String _result = '';
  bool _hasResult = false;
  Workout? _lastParsed;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    if (_result.isNotEmpty) {
      String textToCopy = _result;
      if (_lastParsed != null) {
        final name = _lastParsed!.name;
        final summary = _lastParsed!.summary ?? '';
        final exercises = _lastParsed!.exercises;

        final buffer = StringBuffer();
        buffer.writeln(name);
        if (summary.isNotEmpty) buffer.writeln(summary);
        buffer.writeln();
        for (final e in exercises) {
          final hasCardioData = e.durationMinutes != null && e.durationMinutes! > 0;
          final prefs = ref.read(prefsProvider).valueOrNull;
          final unit = prefs?.weightUnit ?? WeightUnit.kg;
          if (hasCardioData && e.reps == 0) {
            buffer.writeln('- ${e.exerciseName}: ${e.durationMinutes} min');
          } else {
            buffer.writeln('- ${e.exerciseName}: ${e.sets}x${e.reps} @ ${formatWeight(e.weight, unit)}');
          }
        }
        textToCopy = buffer.toString();
      }

      try {
        await Clipboard.setData(ClipboardData(text: textToCopy));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard')),
          );
        }
      } catch (e) {
        if (mounted) {
          _showCopyFallback(textToCopy);
        }
      }
    }
  }

  void _showCopyFallback(String text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Copy Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your browser blocked automatic copying (common on non-secure IP connections). Please select and copy the text below:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                text,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('DONE'),
          ),
        ],
      ),
    );
  }

  Future<void> _accept() async {
    if (_lastParsed == null) return;
    final store = ref.read(storeProvider);

    try {
      final exercises = _lastParsed!.exercises.map((e) {
        final setCount = e.sets <= 0 ? 1 : e.sets;
        return Exercise(
          exerciseName: e.exerciseName,
          sets: setCount,
          reps: e.reps,
          weight: e.weight,
          completed: List.generate(setCount, (_) => false),
          notes: e.notes,
          type: e.type,
          durationMinutes: e.durationMinutes,
        );
      }).toList();

      final session = Workout(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: _lastParsed!.name,
        summary: _lastParsed!.summary,
        durationMinutes: _lastParsed!.durationMinutes,
        date: DateTime.now(),
        exercises: exercises,
        status: WorkoutStatus.active,
      );

      await store.saveActiveSession(session);
      ref.invalidate(activeSessionProvider); // Trigger UI refresh

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan accepted! Check the "Active" tab.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to parse plan for tracker: $e')),
      );
    }
  }

  Workout? _tryParseWorkout(String plan) {
    try {
      var cleaned = plan.trim();

      // 1. Strip Markdown code blocks if present (```json ... ```)
      if (cleaned.contains('```')) {
        final match = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(cleaned);
        if (match != null) {
          cleaned = match.group(1) ?? cleaned;
        }
      }

      // 2. Find the JSON object bounds
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return null;

      cleaned = cleaned.substring(start, end + 1);

      // 3. Basic cleaning for common LLM mistakes
      // Remove trailing commas in objects/arrays: , } or , ]
      cleaned = cleaned.replaceAll(RegExp(r',\s*([}\]])'), r'\1');
      
      // Remove single-line comments // that aren't inside strings (rough approximation)
      cleaned = cleaned.split('\n').map((line) {
        final commentIdx = line.indexOf('//');
        if (commentIdx == -1) return line;
        // Simple check: if // is preceded by odd number of quotes, it might be in a string
        final prefix = line.substring(0, commentIdx);
        if ('"'.allMatches(prefix).length % 2 != 0) return line;
        return prefix;
      }).join('\n');

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return Workout.fromJson(json);
    } catch (e) {
      debugPrint('AI Suggestion parse error: $e');
      return null;
    }
  }

  Future<void> _generate() async {
    final store = ref.read(storeProvider);
    final aiProxy = ref.read(aiProxyProvider);
    
    setState(() {
      _loading = true;
      _result = '';
      _hasResult = false;
    });

    try {
      final prefs = await store.fetchPrefs();
      final workouts = await store.fetchWorkouts();
      
      // Use Cloud Functions proxy for AI calls
      final plan = await aiProxy.generateWorkoutPlan(
        prefs: prefs,
        recentWorkouts: workouts,
      );

      setState(() {
        _result = plan;
        _hasResult = true;
        _lastParsed = _tryParseWorkout(plan);
      });
    } catch (error) {
      setState(() {
        _result = 'Failed to generate plan: $error';
        _hasResult = true;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _refinePlan() async {
    final feedback = _replyController.text.trim();
    if (feedback.isEmpty || _lastParsed == null) return;

    final store = ref.read(storeProvider);
    final aiProxy = ref.read(aiProxyProvider);
    final prefs = await store.fetchPrefs();

    setState(() => _refining = true);

    try {
      // Use Cloud Functions proxy for AI calls
      final currentPlanMap = {
        'name': _lastParsed!.name,
        'summary': _lastParsed!.summary,
        'durationMinutes': _lastParsed!.durationMinutes,
        'exercises': _lastParsed!.exercises.map((e) => {
          'exerciseName': e.exerciseName,
          'sets': e.sets,
          'reps': e.reps,
          'weight': e.weight,
          'type': e.type.name,
          'durationMinutes': e.durationMinutes,
          'notes': e.notes,
        }).toList(),
      };

      final plan = await aiProxy.refineWorkoutPlan(
        prefs: prefs,
        planJson: currentPlanMap,
        feedback: feedback,
      );

      final parsed = _tryParseWorkout(plan);
      if (parsed == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refined plan was not valid JSON.')),
          );
        }
        return;
      }

      setState(() {
        _result = plan;
        _hasResult = true;
        _lastParsed = parsed;
        _replyController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refine plan: $error')),
      );
    } finally {
      if (mounted) setState(() => _refining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Suggestions')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // --- header card ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFF00BFA6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'AI Workout Planner',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Generate a personalised plan based on your goals, equipment, and recent sessions.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _generate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF7C4DFF),
                            disabledBackgroundColor:
                                Colors.white.withValues(alpha: 0.6),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF7C4DFF),
                                  ),
                                )
                              : const Text('Generate Plan'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- parse workout notes ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Parse Workout Notes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Turn pasted notes into structured sets, then save them to history.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LogWorkoutScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                          label: const Text('Parse with AI'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- result area ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (!_hasResult)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.psychology_rounded,
                                  size: 56,
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tap "Generate Plan" to get started',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        _lastParsed != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildPlanPreview(),
                                  const SizedBox(height: 16),
                                  _buildReplyBox(),
                                ],
                              )
                            : Text(
                                _result,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: _result.contains('Failed') ||
                                          _result.contains('Set your')
                                      ? Colors.red.shade300
                                      : Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                      if (_hasResult) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (_result.trim().isNotEmpty)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _copy,
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  label: const Text('Copy Text'),
                                ),
                              ),
                            if (_lastParsed != null) ...[
                              if (_result.trim().isNotEmpty)
                                const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _accept,
                                  icon: const Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Accept Plan'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reply to refine the plan',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _replyController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'e.g., less volume, more cardio, shorter warm-up',
          ),
        ),
        if (_refining) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                'Refining plan...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _refining ? null : _refinePlan,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(_refining ? 'Refining...' : 'Send Reply'),
          ),
        ),
      ],
    );
  }
  Widget _buildPlanPreview() {
    final name = _lastParsed!.name;
    final summary = _lastParsed!.summary ?? '';
    final duration = _lastParsed!.durationMinutes;
    final exercises = _lastParsed!.exercises;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                summary,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        ],
        if (duration is int && duration > 0) ...[
          const SizedBox(height: 6),
          Text(
            'Approx $duration min',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(color: Colors.white10),
        ),
        ...exercises.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    size: 16,
                    color: Color(0xFF7C4DFF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.exerciseName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final p = <String>[];
                          // For cardio/flexibility with duration, show duration instead of sets/reps
                          final hasCardioData = e.durationMinutes != null && e.durationMinutes! > 0;
                          if (!hasCardioData) {
                            if (e.sets > 1) p.add('${e.sets} sets');
                            if (e.reps > 0) p.add('${e.reps} reps');
                          }
                          final prefs = ref.read(prefsProvider).valueOrNull;
                          final unit = prefs?.weightUnit ?? WeightUnit.kg;
                          if (e.weight > 0) p.add(formatWeight(e.weight, unit));
                          if (hasCardioData) p.add('${e.durationMinutes} min');
                          if (p.isEmpty) return const SizedBox.shrink();
                          return Text(
                            p.join(' · '),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
