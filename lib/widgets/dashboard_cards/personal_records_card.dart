import 'package:flutter/material.dart';

import '../../models/user_prefs.dart';
import '../../utils/weight_utils.dart';

class PersonalRecordsCard extends StatelessWidget {
  final List<MapEntry<String, double>> records;
  final WeightUnit weightUnit;
  
  const PersonalRecordsCard({super.key, required this.records, required this.weightUnit});

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
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
                  color: const Color(0xFFFFD600).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: Color(0xFFFFD600), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Personal Records',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            const Text('No records yet — keep lifting!',
                style: TextStyle(fontSize: 13, color: Colors.white54))
          else
            ...records.asMap().entries.map((entry) {
              final idx = entry.key;
              final rec = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(_medals[idx],
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        rec.key,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatWeight(rec.value, weightUnit),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFD600),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
