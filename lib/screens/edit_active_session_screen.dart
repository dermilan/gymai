import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_prefs.dart';
import '../models/workout.dart';
import '../providers.dart';
import '../utils/weight_utils.dart';

class EditActiveSessionScreen extends ConsumerStatefulWidget {
  final Workout session;

  const EditActiveSessionScreen({super.key, required this.session});

  @override
  ConsumerState<EditActiveSessionScreen> createState() => _EditActiveSessionScreenState();
}

class _EditActiveSessionScreenState extends ConsumerState<EditActiveSessionScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _summaryController;
  late final TextEditingController _durationController;
  late List<_EditableExercise> _exercises;
  WeightUnit _weightUnit = WeightUnit.kg;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.session.name);
    _summaryController = TextEditingController(text: widget.session.summary ?? '');
    _durationController = TextEditingController(
      text: widget.session.durationMinutes?.toString() ?? '',
    );
    // Initialize with kg, will be updated in didChangeDependencies
    _exercises = widget.session.exercises
        .map((ex) => _EditableExercise.fromExercise(ex, WeightUnit.kg))
        .toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prefs = ref.read(prefsProvider).valueOrNull;
    final newUnit = prefs?.weightUnit ?? WeightUnit.kg;
    if (newUnit != _weightUnit) {
      _weightUnit = newUnit;
      // Re-initialize exercises with correct unit conversion
      _exercises = widget.session.exercises
          .map((ex) => _EditableExercise.fromExercise(ex, _weightUnit))
          .toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _summaryController.dispose();
    _durationController.dispose();
    for (final ex in _exercises) {
      ex.dispose();
    }
    super.dispose();
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

    final updatedExercises = _exercises.map((editable) {
      final sets = int.tryParse(editable.sets.text.trim()) ?? 1;
      final reps = int.tryParse(editable.reps.text.trim()) ?? 0;
      final displayWeight = double.tryParse(editable.weight.text.trim()) ?? 0;
      // Convert from display unit back to internal kg
      final weight = toInternalWeight(displayWeight, _weightUnit);
      final dur = int.tryParse(editable.durationMinutes.text.trim());
      
      // Keep track of completion state if possible, or reset to match new set count
      List<bool> completion;
      if (sets == editable.originalSets) {
        completion = List.from(editable.originalCompletion);
      } else {
        completion = List.filled(sets, false);
        // Try to preserve partial completion
        for (var i = 0; i < completion.length && i < editable.originalCompletion.length; i++) {
          completion[i] = editable.originalCompletion[i];
        }
      }

      return Exercise(
        exerciseName: editable.name.text.trim().isEmpty ? 'Exercise' : editable.name.text.trim(),
        sets: sets < 1 ? 1 : sets,
        reps: reps,
        weight: weight,
        completed: completion,
        type: editable.type.value,
        durationMinutes: dur,
        notes: editable.notes.text.trim(),
      );
    }).toList();

    final updated = widget.session.copyWith(
      name: name,
      summary: _summaryController.text.trim(),
      durationMinutes: duration,
      exercises: updatedExercises,
    );

    await ref.read(storeProvider).saveActiveSession(updated);
    ref.invalidate(activeSessionProvider);

    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Tracker'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Done'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          // Session Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Global Duration (min)',
                    prefixIcon: Icon(Icons.timer_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Exercises Header
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
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No exercises in this session.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                ),
              ),
            ),

          for (var i = 0; i < _exercises.length; i++)
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

class _EditableExercise {
  final TextEditingController name;
  final TextEditingController sets;
  final TextEditingController reps;
  final TextEditingController weight;
  final TextEditingController durationMinutes;
  final TextEditingController notes;
  final ValueNotifier<ExerciseType> type;
  
  // To preserve completion state if possible
  final int originalSets;
  final List<bool> originalCompletion;

  _EditableExercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.durationMinutes,
    required this.notes,
    required this.type,
    required this.originalSets,
    required this.originalCompletion,
  });

  factory _EditableExercise.fromExercise(Exercise ex, WeightUnit unit) {
    // Convert internal kg to display unit
    final displayWeight = toDisplayWeight(ex.weight, unit);
    return _EditableExercise(
      name: TextEditingController(text: ex.exerciseName),
      sets: TextEditingController(text: ex.sets.toString()),
      reps: TextEditingController(text: ex.reps.toString()),
      weight: TextEditingController(text: displayWeight.toStringAsFixed(1)),
      durationMinutes: TextEditingController(text: ex.durationMinutes?.toString() ?? ''),
      notes: TextEditingController(text: ex.notes),
      type: ValueNotifier(ex.type),
      originalSets: ex.sets,
      originalCompletion: ex.completed ?? [],
    );
  }

  factory _EditableExercise.empty() {
    return _EditableExercise(
      name: TextEditingController(),
      sets: TextEditingController(text: '1'),
      reps: TextEditingController(text: '0'),
      weight: TextEditingController(text: '0'),
      durationMinutes: TextEditingController(),
      notes: TextEditingController(),
      type: ValueNotifier(ExerciseType.strength),
      originalSets: 0,
      originalCompletion: [],
    );
  }

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
    weight.dispose();
    durationMinutes.dispose();
    notes.dispose();
    type.dispose();
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
