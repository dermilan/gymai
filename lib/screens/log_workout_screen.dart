import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_prefs.dart';
import '../models/workout.dart';
import '../providers.dart';
import '../services/ocr_service.dart';
import '../utils/weight_utils.dart';

class LogWorkoutScreen extends ConsumerStatefulWidget {
  const LogWorkoutScreen({super.key});

  @override
  ConsumerState<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends ConsumerState<LogWorkoutScreen> {
  final TextEditingController _pasteController = TextEditingController();
  List<Exercise> _parsedExercises = [];
  Workout? _lastParsedWorkout;
  String _status = '';
  bool _loading = false;
  DateTime _sessionDate = DateTime.now();
  bool _dateWasInferred = false; // True if AI didn't extract a date

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _parseInput() async {
    final input = _pasteController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _parsedExercises = [];
        _status = 'Paste workout text to parse.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Parsing with AI…';
    });

    try {
      final store = ref.read(storeProvider);
      final aiProxy = ref.read(aiProxyProvider);
      final prefs = await store.fetchPrefs();

      final parseTime = DateTime.now();
      final parsed = await aiProxy.parseWorkoutNotes(prefs, input);
      final exercises = _expandParsedExercises(parsed.exercises);
      
      // Detect if date was defaulted (within 30 seconds of parse time)
      final dateDiff = parsed.date.difference(parseTime).abs();
      final wasInferred = dateDiff.inSeconds < 30;
      
      setState(() {
        _parsedExercises = exercises;
        _lastParsedWorkout = parsed;
        _sessionDate = parsed.date;
        _dateWasInferred = wasInferred;
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

  Future<void> _showScanOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _parseImage(fromCamera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _parseImage(fromCamera: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _parseImage({required bool fromCamera}) async {
    setState(() {
      _loading = true;
      _status = 'Scanning photo with AI...';
    });

    try {
      final parseTime = DateTime.now();
      final parsed = await OcrService.pickAndParseImage(fromCamera: fromCamera);
      if (parsed == null) {
        setState(() {
          _loading = false;
          _status = '';
        });
        return;
      }

      final exercises = _expandParsedExercises(parsed.exercises);
      
      // Detect if date was defaulted (within 30 seconds of parse time)
      final dateDiff = parsed.date.difference(parseTime).abs();
      final wasInferred = dateDiff.inSeconds < 30;
      
      setState(() {
        _parsedExercises = exercises;
        _lastParsedWorkout = parsed;
        _sessionDate = parsed.date;
        _dateWasInferred = wasInferred;
        _status = 'Parsed "${parsed.name}" from photo\n${parsed.summary ?? ""}';
      });
    } catch (error) {
      setState(() {
        _status = 'Scan failed: $error';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Exercise> _expandParsedExercises(List<Exercise> parsed) {
    // Each Exercise already has sets, reps, weight - just return as-is
    return parsed;
  }

  Future<void> _saveWorkout() async {
    if (_parsedExercises.isEmpty) {
      setState(() => _status = 'Nothing to save yet.');
      return;
    }

    final log = Workout(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _lastParsedWorkout?.name ?? 'Quick Log',
      summary: _lastParsedWorkout?.summary,
      date: _sessionDate,
      exercises: _parsedExercises,
      durationMinutes: null,
      status: WorkoutStatus.completed,
    );

    await ref.read(storeProvider).saveWorkout(log);
    ref.invalidate(workoutsProvider);
    ref.invalidate(unseenHistoryCountProvider);
    setState(() {
      _status = 'Saved workout with ${_parsedExercises.length} exercises.';
      _parsedExercises = [];
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
      _dateWasInferred = false; // User explicitly set the date
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Paste your workout notes',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      IconButton(
                        onPressed: _loading ? null : _showScanOptions,
                        icon: const Icon(Icons.camera_alt_rounded, size: 20),
                        tooltip: 'Scan Photo',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: cs.primary,
                      ),
                    ],
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
                      if (_dateWasInferred && _parsedExercises.isNotEmpty) ...[
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Colors.amber.shade400,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          _dateWasInferred && _parsedExercises.isNotEmpty
                              ? 'Date not found - using today'
                              : _formatDate(_sessionDate),
                          style: TextStyle(
                            fontSize: 13,
                            color: _dateWasInferred && _parsedExercises.isNotEmpty
                                ? Colors.amber.shade400
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickSessionDateTime,
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(_dateWasInferred && _parsedExercises.isNotEmpty
                            ? 'Set correct date'
                            : 'Pick date'),
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
                  onPressed: _parsedExercises.isEmpty ? null : _saveWorkout,
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
            _parsedExercises.isEmpty
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
                            'Parsed exercises will appear here',
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
                    itemCount: _parsedExercises.length,
                    itemBuilder: (context, index) {
                        final exercise = _parsedExercises[index];
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
                                      exercise.exerciseName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Builder(
                                      builder: (context) {
                                        final p = <String>[];
                                        p.add(exerciseTypeLabel(exercise.type));
                                        if (exercise.sets > 0) p.add('${exercise.sets} sets');
                                        if (exercise.reps > 0) p.add('${exercise.reps} reps');
                                        final prefs = ref.read(prefsProvider).valueOrNull;
                                        final unit = prefs?.weightUnit ?? WeightUnit.kg;
                                        if (exercise.weight > 0) p.add(formatWeight(exercise.weight, unit));
                                        if (exercise.durationMinutes != null && exercise.durationMinutes! > 0) {
                                          p.add('${exercise.durationMinutes} min');
                                        }
                                        return Text(
                                          p.join(' · '),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.withValues(alpha: 0.5),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              if (exercise.notes.isNotEmpty)
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
