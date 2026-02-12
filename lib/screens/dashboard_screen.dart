import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/workout_log.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const _headerGradient = LinearGradient(
    colors: [Color(0xFF00BFA6), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppServices.workoutsRefresh,
      builder: (context, _, __) {
        return FutureBuilder<List<WorkoutLog>>(
          future: AppServices.store.fetchWorkouts(),
          builder: (context, snapshot) {
            final workouts = snapshot.data ?? [];
            final latest = workouts.isNotEmpty ? workouts.first : null;

            // --- weekly stats ---
            final now = DateTime.now();
            final weekday = now.weekday; // 1=Mon, 7=Sun
            final thisWeekStart = DateTime(
              now.year, now.month, now.day,
            ).subtract(Duration(days: weekday - 1));
            final lastWeekStart =
                thisWeekStart.subtract(const Duration(days: 7));

            double thisWeekVol = 0;
            double lastWeekVol = 0;
            for (final w in workouts) {
              if (!w.date.isBefore(thisWeekStart)) {
                thisWeekVol += w.totalVolume;
              } else if (!w.date.isBefore(lastWeekStart)) {
                lastWeekVol += w.totalVolume;
              }
            }

            String trendLabel;
            IconData trendIcon;
            Color trendColor;
            if (lastWeekVol == 0 && thisWeekVol == 0) {
              trendLabel = '—';
              trendIcon = Icons.horizontal_rule_rounded;
              trendColor = const Color(0xFF00E5FF);
            } else if (lastWeekVol == 0) {
              trendLabel = 'New!';
              trendIcon = Icons.trending_up_rounded;
              trendColor = const Color(0xFF00E676);
            } else {
              final pct =
                  ((thisWeekVol - lastWeekVol) / lastWeekVol * 100).round();
              if (pct > 0) {
                trendLabel = '+$pct%';
                trendIcon = Icons.trending_up_rounded;
                trendColor = const Color(0xFF00E676);
              } else if (pct < 0) {
                trendLabel = '$pct%';
                trendIcon = Icons.trending_down_rounded;
                trendColor = const Color(0xFFFF5252);
              } else {
                trendLabel = '0%';
                trendIcon = Icons.trending_flat_rounded;
                trendColor = const Color(0xFF00E5FF);
              }
            }

            return Scaffold(
              appBar: AppBar(title: const Text('Dashboard')),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  // --- gradient welcome card ---
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: _headerGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back 💪',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          workouts.isEmpty
                              ? 'Log your first workout to get started.'
                              : 'You\'ve logged ${workouts.length} workout${workouts.length == 1 ? '' : 's'} so far.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- stat cards row ---
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.fitness_center_rounded,
                          label: 'Workouts',
                          value: '${workouts.length}',
                          accent: const Color(0xFF00BFA6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_fire_department_rounded,
                          label: 'This Week',
                          value: thisWeekVol > 0
                              ? '${(thisWeekVol / 1000).toStringAsFixed(1)}k'
                              : '0',
                          accent: const Color(0xFFFF6D00),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.timer_rounded,
                          label: 'Latest',
                          value: latest?.name ?? '—',
                          accent: const Color(0xFF7C4DFF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: trendIcon,
                          label: 'Trend',
                          value: trendLabel,
                          accent: trendColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // --- weekly focus card ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C4DFF)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: Color(0xFF7C4DFF),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Weekly Focus',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Build consistency. Aim for 3–4 sessions this week.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
