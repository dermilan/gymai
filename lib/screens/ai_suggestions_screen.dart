import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_services.dart';
import '../models/active_session.dart';
import 'log_workout_screen.dart';

class AiSuggestionsScreen extends StatefulWidget {
  const AiSuggestionsScreen({super.key});

  @override
  State<AiSuggestionsScreen> createState() => _AiSuggestionsScreenState();
}

class _AiSuggestionsScreenState extends State<AiSuggestionsScreen> {
  final TextEditingController _replyController = TextEditingController();
  bool _loading = false;
  bool _refining = false;
  String _result = '';
  bool _hasResult = false;
  Map<String, dynamic>? _lastJson;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    if (_result.isNotEmpty) {
      String textToCopy = _result;
      if (_lastJson != null) {
        final name = _lastJson!['name']?.toString() ?? 'Workout Plan';
        final summary = _lastJson!['summary']?.toString() ?? '';
        final exercises = _lastJson!['exercises'] as List? ?? [];

        final buffer = StringBuffer();
        buffer.writeln(name);
        if (summary.isNotEmpty) buffer.writeln(summary);
        buffer.writeln();
        for (final e in exercises) {
          final data = e as Map<String, dynamic>;
          buffer.writeln(
              '- ${data['exerciseName']}: ${data['sets']}x${data['reps']} @ ${data['weight']}kg');
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
    if (_lastJson == null) return;

    try {
      final exercises = (_lastJson!['exercises'] as List? ?? []).map((e) {
        final data = e as Map<String, dynamic>;
        final sets = data['sets'] as int? ?? 1;
        return ActiveExercise(
          exerciseName: data['exerciseName']?.toString() ?? 'Exercise',
          sets: sets,
          reps: data['reps'] as int? ?? 10,
          weight: (data['weight'] as num? ?? 0).toDouble(),
          completed: List.generate(sets, (_) => false),
          notes: data['notes']?.toString(),
        );
      }).toList();

      final session = ActiveSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: _lastJson!['name']?.toString() ?? 'Gym Session',
        summary: _lastJson!['summary']?.toString(),
        durationMinutes: _lastJson!['durationMinutes'] as int?,
        date: DateTime.now(),
        exercises: exercises,
      );

      await AppServices.store.saveActiveSession(session);
      AppServices.workoutsRefresh.value += 1; // Trigger UI refresh

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

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _result = '';
      _hasResult = false;
    });

    try {
      final prefs = await AppServices.store.fetchPrefs();
      if (!prefs.hasApiKey) {
        setState(() {
          _result = 'Set your API key in Settings first.';
          _hasResult = true;
        });
        return;
      }

      final workouts = await AppServices.store.fetchWorkouts();
      final client = AppServices.createAiClient(prefs);
      final plan = await client.generateWorkoutPlan(
        prefs: prefs,
        recentWorkouts: workouts,
      );

      setState(() {
        _result = plan;
        _hasResult = true;
        try {
          // Try to parse JSON for the "Accept" flow
          final start = plan.indexOf('{');
          final end = plan.lastIndexOf('}');
          if (start != -1 && end != -1) {
            _lastJson = jsonDecode(plan.substring(start, end + 1)) as Map<String, dynamic>;
          }
        } catch (_) {
          _lastJson = null;
        }
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
    if (feedback.isEmpty || _lastJson == null) return;

    final prefs = await AppServices.store.fetchPrefs();
    if (!prefs.hasApiKey) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set your API key in Settings first.')),
        );
      }
      return;
    }

    setState(() => _refining = true);

    try {
      final client = AppServices.createAiClient(prefs);
      final plan = await client.refineWorkoutPlan(
        prefs: prefs,
        planJson: _lastJson!,
        feedback: feedback,
      );

      final start = plan.indexOf('{');
      final end = plan.lastIndexOf('}');
      if (start == -1 || end == -1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refined plan was not valid JSON.')),
          );
        }
        return;
      }

      final updated =
          jsonDecode(plan.substring(start, end + 1)) as Map<String, dynamic>;
      setState(() {
        _result = plan;
        _hasResult = true;
        _lastJson = updated;
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
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: const SizedBox(
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
                        _lastJson != null
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
                            if (_lastJson != null) ...[
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
    final name = _lastJson!['name']?.toString() ?? 'Suggested Workout';
    final summary = _lastJson!['summary']?.toString() ?? '';
    final duration = _lastJson!['durationMinutes'];
    final exercises = _lastJson!['exercises'] as List? ?? [];

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
            'Approx ${duration} min',
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
          final data = e as Map<String, dynamic>;
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
                        data['exerciseName']?.toString() ?? 'Exercise',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${data['sets']} sets × ${data['reps']} reps @ ${data['weight']}kg',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
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
