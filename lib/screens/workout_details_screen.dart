import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_prefs.dart';
import '../models/workout.dart';
import '../providers.dart';
import '../utils/weight_utils.dart';
import 'edit_workout_screen.dart';

class WorkoutDetailsScreen extends ConsumerStatefulWidget {
  final Workout workout;

  const WorkoutDetailsScreen({super.key, required this.workout});

  @override
  ConsumerState<WorkoutDetailsScreen> createState() => _WorkoutDetailsScreenState();
}

class _WorkoutDetailsScreenState extends ConsumerState<WorkoutDetailsScreen> {
  late Workout _workout;

  @override
  void initState() {
    super.initState();
    _workout = widget.workout;
  }

  Future<void> _refreshWorkout() async {
    final store = ref.read(storeProvider);
    final workouts = await store.fetchWorkouts();
    final updated = workouts.firstWhere(
      (w) => w.effectiveId == _workout.effectiveId,
      orElse: () => _workout,
    );
    if (mounted) {
      setState(() => _workout = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final exercises = _groupExercises(_workout.exercises);
    final prefs = ref.watch(prefsProvider).valueOrNull;
    final weightUnit = prefs?.weightUnit ?? WeightUnit.kg;
    
    // Watch workouts to trigger refresh when they change
    ref.listen(workoutsProvider, (previous, next) {
      _refreshWorkout();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_workout.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: () => _editWorkout(context),
            tooltip: 'Edit workout',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          // Workout Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_formatDate(_workout.date)} · ${_workout.exercises.length} sets · Vol: ${_workout.totalVolume.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_workout.durationMinutes != null)
                          Row(
                            children: [
                              Icon(Icons.timer_rounded, size: 16, color: Colors.white.withValues(alpha: 0.5)),
                              const SizedBox(width: 4),
                              Text(
                                '${_workout.durationMinutes} min',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (_workout.summary != null && _workout.summary!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _workout.summary!,
                        style: const TextStyle(fontSize: 15, height: 1.4),
                      ),
                    ],
                    if (_workout.aiComment != null && _workout.aiComment!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 16, color: cs.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'AI INSIGHT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: cs.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _workout.aiComment!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.9),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'Exercises',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              ...exercises.map((ex) => _ExerciseDetailCard(exercise: ex, weightUnit: weightUnit)),
            ],
          ),
    );
  }

  void _editWorkout(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditWorkoutScreen(workout: _workout),
      ),
    );
  }

  List<_ExerciseSummary> _groupExercises(List<Exercise> exercises) {
    final List<_ExerciseSummary> result = [];
    final Map<String, List<Exercise>> groups = {};
    final List<String> order = [];

    for (final exercise in exercises) {
      if (!groups.containsKey(exercise.exerciseName)) {
        groups[exercise.exerciseName] = [];
        order.add(exercise.exerciseName);
      }
      groups[exercise.exerciseName]!.add(exercise);
    }

    for (final name in order) {
      result.add(_ExerciseSummary(name: name, exercises: groups[name]!));
    }
    return result;
  }

  String _formatDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, ${d.year} at $h:$m';
  }
}

class _ExerciseSummary {
  final String name;
  final List<Exercise> exercises;

  _ExerciseSummary({required this.name, required this.exercises});
}

class _ExerciseDetailCard extends StatelessWidget {
  final _ExerciseSummary exercise;
  final WeightUnit weightUnit;

  const _ExerciseDetailCard({required this.exercise, required this.weightUnit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...exercise.exercises.asMap().entries.map((entry) {
              final idx = entry.key;
              final ex = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          // Show duration for cardio/flexibility or any exercise with durationMinutes
                          final hasCardioData = ex.durationMinutes != null && ex.durationMinutes! > 0;
                          if (hasCardioData && ex.reps == 0) {
                            return Text(
                              '${ex.durationMinutes} min',
                              style: const TextStyle(fontSize: 14),
                            );
                          }
                          // Regular strength display
                          final parts = <String>[];
                          if (ex.sets > 1 || ex.reps > 0) {
                            parts.add('${ex.sets}x${ex.reps}');
                          }
                          if (ex.weight > 0) {
                            parts.add('@ ${formatWeight(ex.weight, weightUnit)}');
                          }
                          if (hasCardioData) {
                            parts.add('· ${ex.durationMinutes} min');
                          }
                          return Text(
                            parts.join(' '),
                            style: const TextStyle(fontSize: 14),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (exercise.exercises.any((e) => e.notes.isNotEmpty)) ...[
              const Divider(height: 24),
              Text(
                exercise.exercises.firstWhere((e) => e.notes.isNotEmpty).notes,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

