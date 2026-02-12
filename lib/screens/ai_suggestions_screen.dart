import 'package:flutter/material.dart';

import '../app_services.dart';

class AiSuggestionsScreen extends StatefulWidget {
  const AiSuggestionsScreen({super.key});

  @override
  State<AiSuggestionsScreen> createState() => _AiSuggestionsScreenState();
}

class _AiSuggestionsScreenState extends State<AiSuggestionsScreen> {
  bool _loading = false;
  String _result = '';
  bool _hasResult = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Suggestions')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            // --- result area ---
            if (!_hasResult && !_loading)
              Expanded(
                child: Center(
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
              ),

            if (_hasResult)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
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
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
