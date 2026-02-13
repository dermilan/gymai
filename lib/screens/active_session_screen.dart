import 'package:flutter/material.dart';
import '../app_services.dart';
import '../models/active_session.dart';
import '../models/workout_log.dart';
import '../models/set_log.dart';

class ActiveSessionScreen extends StatefulWidget {
  final ActiveSession session;
  final VoidCallback onCleared;

  const ActiveSessionScreen({
    super.key,
    required this.session,
    required this.onCleared,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  late ActiveSession _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  @override
  void didUpdateWidget(covariant ActiveSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id) {
      setState(() => _session = widget.session);
    }
  }

  void _toggleSet(int exerciseIndex, int setIndex) {
    setState(() {
      final updatedExercises = List<ActiveExercise>.from(_session.exercises);
      updatedExercises[exerciseIndex] = updatedExercises[exerciseIndex].toggleSet(setIndex);
      _session = _session.copyWith(exercises: updatedExercises);
    });
    AppServices.store.saveActiveSession(_session);
  }

  Future<void> _finish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish Session?'),
        content: const Text('This will save your progress to history and clear the active tracker.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('FINISH')),
        ],
      ),
    );

    if (confirmed != true) return;

    final List<SetLog> sets = [];
    for (final ex in _session.exercises) {
      for (var i = 0; i < ex.sets; i++) {
        if (ex.completed[i]) {
          sets.add(SetLog(
            exerciseName: ex.exerciseName,
            reps: ex.reps,
            weight: ex.weight,
            type: ex.type,
            notes: ex.notes ?? '',
            durationMinutes: ex.durationMinutes,
          ));
        }
      }
    }

    if (sets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No completed sets to save!')),
      );
      return;
    }

    final prefs = await AppServices.store.fetchPrefs();
    final previousWorkouts = await AppServices.store.fetchWorkouts();
    final previous = previousWorkouts.isNotEmpty
        ? previousWorkouts.first
        : null;

    String? aiComment;
    if (prefs.hasApiKey) {
      try {
        final client = AppServices.createAiClient(prefs);
        final comment = await client.generateSessionComment(
          prefs: prefs,
          current: WorkoutLog(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: _session.name,
            summary: _session.summary,
            date: DateTime.now(),
            sets: sets,
            durationMinutes: _session.durationMinutes,
          ),
          previous: previous,
        );
        if (comment.isNotEmpty) {
          aiComment = comment;
        }
      } catch (_) {
        aiComment = null;
      }
    }

    final log = WorkoutLog(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _session.name,
      summary: _session.summary,
      aiComment: aiComment,
      date: DateTime.now(),
      sets: sets,
      durationMinutes: _session.durationMinutes,
    );

    await AppServices.store.saveWorkout(log);
    await AppServices.store.clearActiveSession();
    AppServices.workoutsRefresh.value += 1;
    widget.onCleared();
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Session?'),
        content: const Text('This will permanently delete the active tracker state.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DISCARD'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AppServices.store.clearActiveSession();
      AppServices.workoutsRefresh.value += 1;
      widget.onCleared();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_session.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _discard,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_session.summary != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _session.summary!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _session.exercises.length,
              itemBuilder: (context, exIndex) {
                final ex = _session.exercises[exIndex];
                return _ExerciseCard(
                  exercise: ex,
                  onToggle: (setIdx) => _toggleSet(exIndex, setIdx),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _finish,
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Finish & Log Session'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final ActiveExercise exercise;
  final Function(int) onToggle;

  const _ExerciseCard({required this.exercise, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.exerciseName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${exercise.reps} reps @ ${exercise.weight}kg',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(exercise.sets, (index) {
                final isDone = exercise.completed[index];
                return InkWell(
                  onTap: () => onToggle(index),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDone 
                        ? const Color(0xFF00BFA6).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDone 
                          ? const Color(0xFF00BFA6) 
                          : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Center(
                      child: isDone
                        ? const Icon(Icons.check_rounded, color: Color(0xFF00BFA6), size: 20)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
