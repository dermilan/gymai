import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout.dart';
import '../providers.dart';
import 'workout_details_screen.dart';

enum HistorySortOrder { newestFirst, oldestFirst }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistorySortOrder _sortOrder = HistorySortOrder.newestFirst;

  List<Workout> _sortWorkouts(List<Workout> workouts) {
    final sorted = List<Workout>.from(workouts);
    sorted.sort((a, b) => _sortOrder == HistorySortOrder.newestFirst
        ? b.date.compareTo(a.date)
        : a.date.compareTo(b.date));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final workoutsAsync = ref.watch(workoutsProvider);
    final rawWorkouts = workoutsAsync.valueOrNull ?? [];
    final workouts = _sortWorkouts(rawWorkouts);
    final store = ref.read(storeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (rawWorkouts.isNotEmpty)
            PopupMenuButton<HistorySortOrder>(
              icon: const Icon(Icons.sort_rounded),
              tooltip: 'Sort',
              onSelected: (order) => setState(() => _sortOrder = order),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: HistorySortOrder.newestFirst,
                  child: Row(
                    children: [
                      Icon(
                        _sortOrder == HistorySortOrder.newestFirst
                            ? Icons.check_rounded
                            : null,
                        size: 18,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('Newest first'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: HistorySortOrder.oldestFirst,
                  child: Row(
                    children: [
                      Icon(
                        _sortOrder == HistorySortOrder.oldestFirst
                            ? Icons.check_rounded
                            : null,
                        size: 18,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('Oldest first'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: workouts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 56,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No workouts yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Log a workout to see it here.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              itemCount: workouts.length,
              itemBuilder: (context, index) {
                final workout = workouts[index];
                final aiComment = workout.aiComment ?? '';

                return Dismissible(
                  key: ValueKey(workout.effectiveId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.delete_rounded,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (_) async {
                    await store.deleteWorkout(workout.effectiveId);
                    ref.invalidate(workoutsProvider);
                    ref.invalidate(unseenHistoryCountProvider);
                  },
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              WorkoutDetailsScreen(workout: workout),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          // gradient accent bar
                          Container(
                            width: 4,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  cs.primary,
                                  cs.secondary,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  workout.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatDate(workout.date)} · ${workout.exercises.length} sets · Vol: ${workout.totalVolume.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                if (aiComment.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.06),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 14,
                                          color: cs.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            aiComment,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white
                                                  .withValues(alpha: 0.8),
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}
