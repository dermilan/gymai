import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/set_log.dart';
import '../models/workout_log.dart';

class EditWorkoutScreen extends StatefulWidget {
  final WorkoutLog workout;

  const EditWorkoutScreen({super.key, required this.workout});

  @override
  State<EditWorkoutScreen> createState() => _EditWorkoutScreenState();
}

class _EditWorkoutScreenState extends State<EditWorkoutScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _durationController;
  late DateTime _sessionDate;
  late List<_EditableSet> _sets;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.workout.name);
    _durationController = TextEditingController(
      text: widget.workout.durationMinutes?.toString() ?? '',
    );
    _sessionDate = widget.workout.date;
    _sets = widget.workout.sets.map(_EditableSet.fromSet).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    for (final set in _sets) {
      set.dispose();
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

  void _addSet() {
    setState(() {
      _sets.add(_EditableSet.empty());
    });
  }

  void _removeSet(int index) {
    setState(() {
      _sets[index].dispose();
      _sets.removeAt(index);
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim().isEmpty
        ? 'Workout'
        : _nameController.text.trim();
    final duration = int.tryParse(_durationController.text.trim());

    final updatedSets = _sets.map((editable) {
      final reps = int.tryParse(editable.reps.text.trim()) ?? 0;
      final weight = double.tryParse(editable.weight.text.trim()) ?? 0;
      final dur = int.tryParse(editable.durationMinutes.text.trim());
      final exercise = editable.name.text.trim().isEmpty
          ? 'Exercise'
          : editable.name.text.trim();
      return SetLog(
        exerciseName: exercise,
        reps: reps,
        weight: weight,
        notes: editable.notes.text.trim(),
        type: editable.type.value,
        durationMinutes: dur,
      );
    }).toList();

    final updated = WorkoutLog(
      id: widget.workout.id ?? widget.workout.effectiveId,
      name: name,
      date: _sessionDate,
      sets: updatedSets,
      durationMinutes: duration,
    );

    await AppServices.store.updateWorkout(updated);
    AppServices.workoutsRefresh.value += 1;

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
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save'),
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

          // --- sets header ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.format_list_numbered_rounded,
                      size: 16,
                      color: cs.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Sets (${_sets.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _addSet,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add set'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (_sets.isEmpty)
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
                  'No sets yet. Tap "Add set" to create one.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),

          for (var i = 0; i < _sets.length; i += 1)
            _SetCard(
              index: i,
              editable: _sets[i],
              onRemove: () => _removeSet(i),
            ),
        ],
      ),
    );
  }
}

// -- helper types ------------------------------------------------------------

class _EditableSet {
  final TextEditingController name;
  final TextEditingController reps;
  final TextEditingController weight;
  final TextEditingController notes;
  final ValueNotifier<ExerciseType> type;
  final TextEditingController durationMinutes;

  _EditableSet({
    required this.name,
    required this.reps,
    required this.weight,
    required this.notes,
    required this.type,
    required this.durationMinutes,
  });

  factory _EditableSet.fromSet(SetLog set) {
    return _EditableSet(
      name: TextEditingController(text: set.exerciseName),
      reps: TextEditingController(text: set.reps.toString()),
      weight: TextEditingController(text: set.weight.toString()),
      notes: TextEditingController(text: set.notes),
      type: ValueNotifier(set.type),
      durationMinutes: TextEditingController(
        text: set.durationMinutes?.toString() ?? '',
      ),
    );
  }

  factory _EditableSet.empty() {
    return _EditableSet(
      name: TextEditingController(),
      reps: TextEditingController(),
      weight: TextEditingController(),
      notes: TextEditingController(),
      type: ValueNotifier(ExerciseType.strength),
      durationMinutes: TextEditingController(),
    );
  }

  void dispose() {
    name.dispose();
    reps.dispose();
    weight.dispose();
    notes.dispose();
    type.dispose();
    durationMinutes.dispose();
  }
}

class _SetCard extends StatelessWidget {
  final int index;
  final _EditableSet editable;
  final VoidCallback onRemove;

  const _SetCard({
    required this.index,
    required this.editable,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Set ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: cs.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: Colors.red.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<ExerciseType>(
            valueListenable: editable.type,
            builder: (context, value, _) {
              return DropdownButtonFormField<ExerciseType>(
                initialValue: value,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  prefixIcon: Icon(Icons.category_rounded, size: 20),
                ),
                items: ExerciseType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(exerciseTypeLabel(type)),
                  );
                }).toList(),
                onChanged: (next) {
                  if (next != null) editable.type.value = next;
                },
              );
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: editable.name,
            decoration: const InputDecoration(
              labelText: 'Exercise name',
              prefixIcon: Icon(Icons.fitness_center_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: editable.reps,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: editable.weight,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: editable.durationMinutes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Duration (min)',
              prefixIcon: Icon(Icons.timer_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: editable.notes,
            decoration: const InputDecoration(
              labelText: 'Notes',
              prefixIcon: Icon(Icons.note_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
