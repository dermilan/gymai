import 'package:flutter/material.dart';

class RestDaysCard extends StatelessWidget {
  final int daysSinceLast;
  
  const RestDaysCard({super.key, required this.daysSinceLast});

  @override
  Widget build(BuildContext context) {
    String title;
    String desc;
    IconData icon;
    Color accent;

    if (daysSinceLast < 0) {
      title = 'No Workouts Yet';
      desc = 'Log your first workout to start tracking rest days.';
      icon = Icons.bedtime_rounded;
      accent = const Color(0xFF546E7A);
    } else if (daysSinceLast == 0) {
      title = 'On Fire! 🔥';
      desc = 'You trained today — great job. Listen to your body for tomorrow.';
      icon = Icons.bolt_rounded;
      accent = const Color(0xFFFF6D00);
    } else if (daysSinceLast <= 2) {
      title = 'Good Recovery';
      desc = '$daysSinceLast day${daysSinceLast == 1 ? '' : 's'} of rest. Your muscles are recharging.';
      icon = Icons.battery_charging_full_rounded;
      accent = const Color(0xFF00E676);
    } else {
      title = 'Time to Train! 💪';
      desc = 'It\'s been $daysSinceLast days since your last session. Let\'s go!';
      icon = Icons.directions_run_rounded;
      accent = const Color(0xFFFF5252);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
