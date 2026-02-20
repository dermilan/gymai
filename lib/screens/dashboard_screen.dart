import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_card_config.dart';
import '../models/user_prefs.dart';
import '../models/workout.dart';
import '../providers.dart';
import '../utils/dashboard_stats.dart';
import '../widgets/dashboard_cards/dashboard_cards.dart';
import 'dashboard_customize_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _headerGradient = LinearGradient(
    colors: [Color(0xFF00BFA6), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutsProvider);
    final prefsAsync = ref.watch(prefsProvider);
    final layoutAsync = ref.watch(dashboardLayoutProvider);

    final workouts = workoutsAsync.valueOrNull ?? [];
    final prefs = prefsAsync.valueOrNull;
    final layout = layoutAsync.valueOrNull ?? DashboardCardConfig.defaultLayout();
    final userName = prefs?.preferredName ?? 'Champ';
    final nameLabel = userName.isNotEmpty ? userName : 'Champ';

    // -- Calculate stats for display ---------------------------------
    final now = DateTime.now();
    final startOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfThisWeek = startOfThisWeek.add(const Duration(days: 7));

    int thisWeekCount = 0;
    double thisWeekVol = 0;

    for (final w in workouts) {
      if (w.status == WorkoutStatus.completed &&
          w.date.isAfter(startOfThisWeek) &&
          w.date.isBefore(endOfThisWeek)) {
        thisWeekCount++;
        thisWeekVol += w.totalVolume;
      }
    }

    final targetDays = prefs?.daysPerWeek ?? 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_customize_rounded),
            tooltip: 'Customize Dashboard',
            onPressed: () => showDashboardCustomizeSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // --- gradient welcome card (always first) ---
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: _headerGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $nameLabel 💪',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  thisWeekCount >= targetDays
                      ? 'You\'ve crushed your goal this week! Keep that momentum.'
                      : 'Let\'s keep working toward your $targetDays-day goal.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- configurable cards ---
          ..._buildDynamicCards(
            layout,
            workouts,
            prefs,
            thisWeekCount,
            targetDays,
            thisWeekVol,
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
      DashboardCardId id,
      List<Workout> workouts,
      UserPrefs? prefs,
      int thisWeekCount,
      int targetDays,
      double thisWeekVol) {
    // Re-calculate derived values as needed for specific cards
    final latest = workouts.isEmpty ? null : workouts.first;
    final latestTimeLabel = latest != null
        ? DashboardStats.formatRelativeTime(latest.date)
        : 'No records';

    switch (id) {
      case DashboardCardId.goalProgress:
        return StatCard(
          icon: Icons.calendar_today_rounded,
          label: 'Goal Progress',
          value: '$thisWeekCount / $targetDays',
          subValue: 'Sessions this week',
          accent: const Color(0xFF00BFA6),
        );
      case DashboardCardId.weeklyVolume:
        return StatCard(
          icon: Icons.local_fire_department_rounded,
          label: 'Weekly Vol',
          value: thisWeekVol > 0
              ? '${(thisWeekVol / 1000).toStringAsFixed(1)}k'
              : '0',
          subValue: '${workouts.length} total sessions',
          accent: const Color(0xFFFF6D00),
        );
      case DashboardCardId.lastSession:
        return StatCard(
          icon: Icons.history_rounded,
          label: 'Last Session',
          value: latest?.name ?? '—',
          subValue: latestTimeLabel,
          accent: const Color(0xFF7C4DFF),
        );
      case DashboardCardId.volTrend:
        final (trendLabel, _, trendColor, trendIcon) =
            DashboardStats.calculateTrendStats(workouts, thisWeekVol);
        return StatCard(
          icon: trendIcon,
          label: 'Vol Trend',
          value: trendLabel,
          subValue: 'vs last week',
          accent: trendColor,
        );
      case DashboardCardId.weeklyFocus:
        final goalMet = thisWeekCount >= targetDays;
        final focusTitle = goalMet ? 'Weekly Goal Met!' : 'Weekly Progress';
        final focusDesc = goalMet
            ? 'Great work! You\'ve hit your $targetDays-day target. Focus on active recovery now.'
            : 'You\'ve completed $thisWeekCount of $targetDays sessions. You can do it!';
        final focusIcon =
            goalMet ? Icons.verified_rounded : Icons.emoji_events_rounded;
        final focusColor =
            goalMet ? const Color(0xFF00BFA6) : const Color(0xFF7C4DFF);

        return Container(
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
                  color: focusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(focusIcon, color: focusColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      focusTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      focusDesc,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case DashboardCardId.streak:
        return StreakCard(streak: DashboardStats.calculateStreak(workouts, targetDays));
      case DashboardCardId.personalRecords:
        return PersonalRecordsCard(
          records: DashboardStats.getPersonalRecords(workouts),
          weightUnit: prefs?.weightUnit ?? WeightUnit.kg,
        );
      case DashboardCardId.exerciseSplit:
        return ExerciseSplitBar(split: DashboardStats.getExerciseSplit(workouts));
      case DashboardCardId.favoriteExercises:
        return FavoriteExercisesCard(
            favorites: DashboardStats.getFavoriteExercises(workouts));
      case DashboardCardId.restDays:
        return RestDaysCard(
            daysSinceLast: DashboardStats.getDaysSinceLastWorkout(workouts));
      case DashboardCardId.volumeTrendChart:
        return VolumeTrendCard(
          dataPoints: DashboardStats.getVolumeTrendData(workouts),
          weightUnit: prefs?.weightUnit ?? WeightUnit.kg,
        );
    }
  }

  List<Widget> _buildDynamicCards(
    List<DashboardCardConfig> layout,
    List<Workout> workouts,
    UserPrefs? prefs,
    int thisWeekCount,
    int targetDays,
    double thisWeekVol,
  ) {
    final widgets = <Widget>[];
    final visible = layout.where((c) => c.visible).toList();
    var i = 0;

    while (i < visible.length) {
      final current = visible[i];

      // If current is compact, check if we can pair it
      if (current.isCompact) {
        // Check for next compact card
        DashboardCardConfig? next;
        if (i + 1 < visible.length && visible[i + 1].isCompact) {
          next = visible[i + 1];
        }

        if (next != null) {
          // Pair them
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildCard(current.id, workouts, prefs, thisWeekCount,
                      targetDays, thisWeekVol),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCard(next.id, workouts, prefs, thisWeekCount,
                      targetDays, thisWeekVol),
                ),
              ],
            ),
          ));
          i += 2; // Consumed two
        } else {
          // Single compact card - render half width to respect "compact" nature
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildCard(current.id, workouts, prefs, thisWeekCount,
                      targetDays, thisWeekVol),
                ),
                const SizedBox(width: 12),
                const Spacer(), // Empty space for missing pair
              ],
            ),
          ));
          i++;
        }
      } else {
        // Full width card
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildCard(current.id, workouts, prefs, thisWeekCount,
              targetDays, thisWeekVol),
        ));
        i++;
      }
    }
    return widgets;
  }
}
