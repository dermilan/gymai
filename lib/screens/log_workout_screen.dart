import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/parsed_workout.dart';
import '../models/parsed_set.dart';
import '../models/set_log.dart';
import '../models/workout_log.dart';

class LogWorkoutScreen extends StatefulWidget {
  const LogWorkoutScreen({super.key});

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  final TextEditingController _pasteController = TextEditingController();
  List<SetLog> _parsedSets = [];
  ParsedWorkout? _lastParsedWorkout;
  String _status = '';
  bool _loading = false;
  DateTime _sessionDate = DateTime.now();

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _parseInput() async {
    final input = _pasteController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _parsedSets = [];
        _status = 'Paste workout text to parse.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Parsing with AI…';
    });

    try {
      final prefs = await AppServices.store.fetchPrefs();
      if (!prefs.hasApiKey) {
        setState(() => _status = 'Set your API key in Settings first.');
        return;
      }

      final client = AppServices.createAiClient(prefs);
      final parsed = await client.parseWorkoutNotes(prefs, input);
      final sets = _expandParsedSets(parsed.sets);
      setState(() {
        _parsedSets = sets;
        _lastParsedWorkout = parsed;
        if (parsed.sessionDate != null) {
          _sessionDate = parsed.sessionDate!;
        }
        _status = 'Parsed "${parsed.name}"\n${parsed.summary ?? "No summary"}';
      });
    } catch (error) {
      setState(() {
        _status = 'Parse failed: $error';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  List<SetLog> _expandParsedSets(List<ParsedSet> parsed) {
    final sets = <SetLog>[];
    for (final entry in parsed) {
      final count = entry.sets <= 0 ? 1 : entry.sets;
      for (var i = 0; i < count; i += 1) {
        sets.add(SetLog(
          exerciseName: entry.exerciseName,
          reps: entry.reps,
          weight: entry.weight,
          notes: entry.notes,
          type: entry.type,
          durationMinutes:
              entry.durationMinutes > 0 ? entry.durationMinutes : null,
        ));
      }
    }
    return sets;
  }

  Future<void> _saveWorkout() async {
    if (_parsedSets.isEmpty) {
      setState(() => _status = 'Nothing to save yet.');
      return;
    }

    final log = WorkoutLog(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _lastParsedWorkout?.name ?? 'Quick Log',
      summary: _lastParsedWorkout?.summary,
      date: _sessionDate,
      sets: _parsedSets,
      durationMinutes: null,
    );

    await AppServices.store.saveWorkout(log);
    AppServices.workoutsRefresh.value += 1;
    setState(() {
      _status = 'Saved workout with ${_parsedSets.length} sets.';
      _parsedSets = [];
      _pasteController.clear();
    });
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Log Workout')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // --- input card ---
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paste your workout notes',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pasteController,
                    maxLines: 5,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Bench 3x5 185\nRow 3x10 135',
                      fillColor: const Color(0xFF16161F),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
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
                ],
              ),
            ),

            const SizedBox(height: 12),

            // --- action buttons ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _parseInput,
                    icon: _loading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(_loading ? 'Parsing…' : 'Parse with AI'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _parsedSets.isEmpty ? null : _saveWorkout,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save'),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // --- status chip ---
            if (_status.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _status.contains('failed') || _status.contains('Set your')
                      ? Colors.red.withValues(alpha: 0.15)
                      : cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 13,
                    color: _status.contains('failed') || _status.contains('Set your')
                        ? Colors.red.shade300
                        : cs.primary,
                  ),
                ),
              ),

            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 4),

            // --- parsed sets list ---
            _parsedSets.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fitness_center_rounded,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Parsed sets will appear here',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _parsedSets.length,
                    itemBuilder: (context, index) {
                        final set = _parsedSets[index];
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 300 + index * 50),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E2A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      set.exerciseName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${exerciseTypeLabel(set.type)} · '
                                      '${set.reps} reps @ ${set.weight}'
                                      '${set.durationMinutes == null ? '' : ' · ${set.durationMinutes} min'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (set.notes.isNotEmpty)
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
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
