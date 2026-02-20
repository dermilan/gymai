import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_prefs.dart';
import '../models/workout.dart';
import '../providers.dart';
import '../utils/weight_utils.dart';
import 'edit_active_session_screen.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  final Workout session;
  final VoidCallback onCleared;

  const ActiveSessionScreen({
    super.key,
    required this.session,
    required this.onCleared,
  });

  @override
  ConsumerState<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  late Workout _session;

  bool _showSummary = true;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  @override
  void didUpdateWidget(covariant ActiveSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      setState(() => _session = widget.session);
    }
  }

  void _toggleSet(int exerciseIndex, int setIndex) {
    final store = ref.read(storeProvider);
    setState(() {
      final updatedExercises = List<Exercise>.from(_session.exercises);
      updatedExercises[exerciseIndex] = updatedExercises[exerciseIndex].toggleSet(setIndex);
      _session = _session.copyWith(exercises: updatedExercises);
    });
    store.saveActiveSession(_session);
  }

  void _reorderExercises(int oldIndex, int newIndex) {
    final store = ref.read(storeProvider);
    setState(() {
      final updatedExercises = List<Exercise>.from(_session.exercises);
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = updatedExercises.removeAt(oldIndex);
      updatedExercises.insert(newIndex, moved);
      _session = _session.copyWith(exercises: updatedExercises);
    });
    store.saveActiveSession(_session);
  }

  Future<void> _finish() async {
    final store = ref.read(storeProvider);
    final aiProxy = ref.read(aiProxyProvider);
    
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

    final List<Exercise> completedExercises = [];
    for (final ex in _session.exercises) {
      int completedSets = 0;
      for (var i = 0; i < ex.sets; i++) {
        if (ex.completed != null && ex.completed![i]) {
          completedSets++;
        }
      }
      if (completedSets > 0) {
        completedExercises.add(ex.copyWith(sets: completedSets));
      }
    }

    if (completedExercises.isEmpty) {
      if (!mounted) return;
      final markAll = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No sets marked done'),
          content: const Text(
            'Would you like to mark all exercises as done so the session can be logged?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('NOT NOW')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('MARK ALL DONE'),
            ),
          ],
        ),
      );

      if (markAll == true) {
        final updatedExercises = _session.exercises
            .map((ex) => ex.copyWith(completed: List<bool>.filled(ex.sets, true)))
            .toList();
        _session = _session.copyWith(exercises: updatedExercises);
        store.saveActiveSession(_session);

        completedExercises.clear();
        for (final ex in _session.exercises) {
          completedExercises.add(ex);
        }
      }

      if (completedExercises.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No completed sets to save!')),
        );
        return;
      }
    }

    final prefs = await store.fetchPrefs();
    final previousWorkouts = await store.fetchWorkouts();
    final previous = previousWorkouts.isNotEmpty
        ? previousWorkouts.first
        : null;

    String? aiComment;
    try {
      debugPrint('Generating AI comment for session...');
      final comment = await aiProxy.generateSessionComment(
        prefs: prefs,
        current: Workout(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: _session.name,
          summary: _session.summary,
          date: DateTime.now(),
          exercises: completedExercises,
          durationMinutes: _session.durationMinutes,
          status: WorkoutStatus.completed,
        ),
        previous: previous,
      );
      debugPrint('AI comment received: $comment');
      if (comment.isNotEmpty) {
        aiComment = comment;
      }
    } catch (e) {
      debugPrint('AI comment error: $e');
      aiComment = null;
    }

    final log = Workout(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _session.name,
      summary: _session.summary,
      aiComment: aiComment,
      date: DateTime.now(),
      exercises: completedExercises,
      durationMinutes: _session.durationMinutes,
      status: WorkoutStatus.completed,
    );

    await store.saveWorkout(log);
    
    // Start global celebration!
    ref.read(confettiTriggerProvider.notifier).state++;
    
    // Wait for animation to be visible
    await Future.delayed(const Duration(milliseconds: 2000));

    await store.clearActiveSession();
    ref.invalidate(workoutsProvider);
    ref.invalidate(activeSessionProvider);
    ref.invalidate(unseenHistoryCountProvider);

    if (!mounted) return;
    widget.onCleared();
  }

  Future<void> _discard() async {
    final store = ref.read(storeProvider);
    
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
      await store.clearActiveSession();
      ref.invalidate(workoutsProvider);
      ref.invalidate(activeSessionProvider);
      widget.onCleared();
    }
  }

  Future<void> _editSession() async {
    final updated = await Navigator.of(context).push<Workout>(
      MaterialPageRoute(
        builder: (context) => EditActiveSessionScreen(session: _session),
      ),
    );

    if (updated != null && mounted) {
      setState(() => _session = updated);
    }
  }


  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider).valueOrNull;
    final weightUnit = prefs?.weightUnit ?? WeightUnit.kg;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_session.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: _editSession,
            tooltip: 'Edit session',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _discard,
            tooltip: 'Discard',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_session.summary != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: _showSummary ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showSummary = !_showSummary),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Session Instructions',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const Spacer(),
                            AnimatedRotation(
                              duration: const Duration(milliseconds: 200),
                              turns: _showSummary ? 0.5 : 0,
                              child: Icon(
                                Icons.expand_more_rounded,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: _showSummary
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: Text(
                                  _session.summary!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    height: 1.4,
                                  ),
                                ),
                              )
                            : const SizedBox(width: double.infinity, height: 0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _session.exercises.length,
              onReorder: _reorderExercises,
              buildDefaultDragHandles: false,
              itemBuilder: (context, exIndex) {
                final ex = _session.exercises[exIndex];
                return _ExerciseCard(
                  key: ObjectKey(ex),
                  exercise: ex,
                  index: exIndex,
                  weightUnit: weightUnit,
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
  final Exercise exercise;
  final int index;
  final WeightUnit weightUnit;
  final Function(int) onToggle;

  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.index,
    required this.weightUnit,
    required this.onToggle,
  });

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
                Builder(
                  builder: (context) {
                    final parts = <String>[];
                    // For cardio with duration, show duration instead of reps
                    final hasCardioData = exercise.durationMinutes != null && exercise.durationMinutes! > 0;
                    if (!hasCardioData && exercise.reps > 0) parts.add('${exercise.reps} reps');
                    if (exercise.weight > 0) parts.add(formatWeight(exercise.weight, weightUnit));
                    if (hasCardioData) {
                      parts.add('${exercise.durationMinutes} min');
                    }
                    if (parts.isEmpty) return const SizedBox.shrink();
                    return Text(
                      parts.join(' · '),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_handle_rounded,
                    size: 16,
                    color: Color(0x66FFFFFF),
                  ),
                ),
              ],
            ),
            if (exercise.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  exercise.notes,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(exercise.sets, (index) {
                final isDone = exercise.completed != null && exercise.completed![index];
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
