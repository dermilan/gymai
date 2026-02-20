import 'package:flutter/material.dart';

class FavoriteExercisesCard extends StatelessWidget {
  final List<MapEntry<String, int>> favorites;
  
  const FavoriteExercisesCard({super.key, required this.favorites});

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
                  color: const Color(0xFF00BFA6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: Color(0xFF00BFA6), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Favorite Exercises',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (favorites.isEmpty)
            const Text('No data yet',
                style: TextStyle(fontSize: 13, color: Colors.white54))
          else
            ...favorites.map((fav) {
              final maxCount = favorites.first.value;
              final ratio = maxCount > 0 ? fav.value / maxCount : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(fav.key,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                        Text('${fav.value}×',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00BFA6),
                            )),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.06),
                        valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF00BFA6)),
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
