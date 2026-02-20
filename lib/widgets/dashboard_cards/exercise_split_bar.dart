import 'package:flutter/material.dart';
import '../../models/workout.dart' show ExerciseType, exerciseTypeLabel;

class ExerciseSplitBar extends StatelessWidget {
  final Map<ExerciseType, int> split;
  
  const ExerciseSplitBar({super.key, required this.split});

  static const _colors = {
    ExerciseType.strength: Color(0xFF7C4DFF),
    ExerciseType.cardio: Color(0xFF00E676),
    ExerciseType.flexibility: Color(0xFF00E5FF),
  };

  @override
  Widget build(BuildContext context) {
    final total = split.values.fold(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pie_chart_rounded,
                    color: Color(0xFF7C4DFF), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Exercise Split',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (total == 0)
            const Text('No data yet',
                style: TextStyle(fontSize: 13, color: Colors.white54))
          else ...[
            // segmented bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: ExerciseType.values
                      .where((t) => (split[t] ?? 0) > 0)
                      .map((t) {
                    final ratio = (split[t] ?? 0) / total;
                    return Expanded(
                      flex: (ratio * 1000).round(),
                      child: Container(color: _colors[t]),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: ExerciseType.values
                  .where((t) => (split[t] ?? 0) > 0)
                  .map((t) {
                final pct = ((split[t] ?? 0) / total * 100).round();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _colors[t],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${exerciseTypeLabel(t)} $pct%',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
