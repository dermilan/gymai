import 'parsed_set.dart';

class ParsedWorkout {
  final DateTime? sessionDate;
  final List<ParsedSet> sets;

  const ParsedWorkout({
    required this.sessionDate,
    required this.sets,
  });

  factory ParsedWorkout.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final rawDate = json['sessionDate'];
    if (rawDate is String && rawDate.trim().isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate.trim());
    }

    final rawSets = json['sets'];
    final list = rawSets is List ? rawSets : const [];

    return ParsedWorkout(
      sessionDate: parsedDate,
      sets: list
          .whereType<Map<String, dynamic>>()
          .map(ParsedSet.fromJson)
          .toList(),
    );
  }
}
