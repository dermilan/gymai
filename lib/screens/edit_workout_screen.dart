import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_prefs.dart';
import '../models/workout.dart';
import '../providers.dart';
import '../utils/weight_utils.dart';

class EditWorkoutScreen extends ConsumerStatefulWidget {
  final Workout workout;

  const EditWorkoutScreen({super.key, required this.workout});

  @override
  ConsumerState<EditWorkoutScreen> createState() => _EditWorkoutScreenState();
}

class _EditWorkoutScreenState extends ConsumerState<EditWorkoutScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _summaryController;
  late final TextEditingController _aiCommentController;
  late final TextEditingController _durationController;
  late DateTime _sessionDate;
  late List<_EditableExercise> _exercises;
  WeightUnit _weightUnit = WeightUnit.kg;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.workout.name);
    _summaryController = TextEditingController(text: widget.workout.summary ?? '');
    _aiCommentController =
        TextEditingController(text: widget.workout.aiComment ?? '');
    _durationController = TextEditingController(
      text: widget.workout.durationMinutes?.toString() ?? '',
    );
    _sessionDate = widget.workout.date;
    _exercises = _groupExercises(widget.workout.exercises, WeightUnit.kg);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prefs = ref.read(prefsProvider).valueOrNull;
    final newUnit = prefs?.weightUnit ?? WeightUnit.kg;
    if (newUnit != _weightUnit) {
      _weightUnit = newUnit;
      _exercises = _groupExercises(widget.workout.exercises, _weightUnit);
    }
  }

  List<_EditableExercise> _groupExercises(List<Exercise> exercises, WeightUnit unit) {
    final List<_EditableExercise> result = [];
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
      final group = groups[name]!;
      final first = group.first;
      final totalSets = group.fold(0, (sum, ex) => sum + ex.sets);
      // Convert internal kg to display unit
      final displayWeight = toDisplayWeight(first.weight, unit);
      result.add(_EditableExercise(
        name: TextEditingController(text: first.exerciseName),
        sets: TextEditingController(text: totalSets.toString()),
        reps: TextEditingController(text: first.reps.toString()),
        weight: TextEditingController(text: displayWeight.toStringAsFixed(1)),
        notes: TextEditingController(text: first.notes),
        type: ValueNotifier(first.type),
        durationMinutes: TextEditingController(
          text: first.durationMinutes?.toString() ?? '',
        ),
      ));
    }
    return result;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _summaryController.dispose();
    _aiCommentController.dispose();
    _durationController.dispose();
    for (final ex in _exercises) {
      ex.dispose();
    }
    super.dispose();
  }

  Future<void> _pickSessionDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _sessionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_sessionDate),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _sessionDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _addExercise() {
    setState(() {
      _exercises.add(_EditableExercise.empty());
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises[index].dispose();
      _exercises.removeAt(index);
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim().isEmpty
        ? 'Workout'
        : _nameController.text.trim();
    final duration = int.tryParse(_durationController.text.trim());

    final List<Exercise> updatedExercises = [];
    for (final editable in _exercises) {
      final setsCount = int.tryParse(editable.sets.text.trim()) ?? 1;
      final reps = int.tryParse(editable.reps.text.trim()) ?? 0;
      final displayWeight = double.tryParse(editable.weight.text.trim()) ?? 0;
      // Convert from display unit back to internal kg
      final weight = toInternalWeight(displayWeight, _weightUnit);
      final dur = int.tryParse(editable.durationMinutes.text.trim());
      final exerciseName = editable.name.text.trim().isEmpty
          ? 'Exercise'
          : editable.name.text.trim();
      
      updatedExercises.add(Exercise(
        exerciseName: exerciseName,
        sets: setsCount < 1 ? 1 : setsCount,
        reps: reps,
        weight: weight,
        notes: editable.notes.text.trim(),
        type: editable.type.value,
        durationMinutes: dur,
      ));
    }

    final updated = Workout(
      id: widget.workout.id ?? widget.workout.effectiveId,
      name: name,
      summary: _summaryController.text.trim(),
      aiComment: _aiCommentController.text.trim(),
      date: _sessionDate,
      exercises: updatedExercises,
      durationMinutes: duration,
      status: WorkoutStatus.completed,
    );

    await ref.read(storeProvider).updateWorkout(updated);
    ref.invalidate(workoutsProvider);

    if (!mounted) return;
    Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Workout'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Done'),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          // --- workout info card ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Workout name',
                    prefixIcon: Icon(Icons.label_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _summaryController,
                  decoration: const InputDecoration(
                    labelText: 'Summary',
                    prefixIcon: Icon(Icons.description_rounded, size: 20),
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _aiCommentController,
                  decoration: const InputDecoration(
                    labelText: 'AI Comment',
                    prefixIcon: Icon(Icons.chat_bubble_rounded, size: 20),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatDate(_sessionDate),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickSessionDateTime,
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: const Text('Pick date'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                    prefixIcon: Icon(Icons.timer_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- exercise header ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Exercises',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Exercise'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (_exercises.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Center(
                child: Text(
                  'No exercises yet. Tap "Add Exercise" to create one.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),

          for (var i = 0; i < _exercises.length; i += 1)
            _ExerciseEditCard(
              index: i,
              editable: _exercises[i],
              onRemove: () => _removeExercise(i),
              weightUnit: _weightUnit,
            ),
        ],
      ),
    );
  }
}

// -- helper types ------------------------------------------------------------

class _EditableExercise {
  final TextEditingController name;
  final TextEditingController sets;
  final TextEditingController reps;
  final TextEditingController weight;
  final TextEditingController notes;
  final ValueNotifier<ExerciseType> type;
  final TextEditingController durationMinutes;

  _EditableExercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.notes,
    required this.type,
    required this.durationMinutes,
  });

  factory _EditableExercise.empty() {
    return _EditableExercise(
      name: TextEditingController(),
      sets: TextEditingController(text: '1'),
      reps: TextEditingController(),
      weight: TextEditingController(),
      notes: TextEditingController(),
      type: ValueNotifier(ExerciseType.strength),
      durationMinutes: TextEditingController(),
    );
  }

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
    weight.dispose();
    notes.dispose();
    type.dispose();
    durationMinutes.dispose();
  }
}

class _ExerciseEditCard extends StatelessWidget {
  final int index;
  final _EditableExercise editable;
  final VoidCallback onRemove;
  final WeightUnit weightUnit;

  const _ExerciseEditCard({
    required this.index,
    required this.editable,
    required this.onRemove,
    required this.weightUnit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: editable.name,
                    decoration: const InputDecoration(
                      hintText: 'Exercise name',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const Divider(),
            ValueListenableBuilder<ExerciseType>(
              valueListenable: editable.type,
              builder: (context, val, _) {
                return Row(
                  children: [
                    const Icon(Icons.category_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<ExerciseType>(
                        value: val,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: ExerciseType.values.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(exerciseTypeLabel(t)),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) editable.type.value = v;
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: editable.sets,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sets'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: editable.reps,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Reps'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: editable.weight,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Weight (${weightUnitLabel(weightUnit)})',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: editable.durationMinutes,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration (min)',
                      prefixIcon: Icon(Icons.timer_rounded, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: editable.notes,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      prefixIcon: Icon(Icons.note_rounded, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
