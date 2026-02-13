import 'parsed_set.dart';

class ParsedWorkout {
  final DateTime? sessionDate;
  final String? name;
  final String? summary;
  final List<ParsedSet> sets;

  const ParsedWorkout({
    required this.sessionDate,
    this.name,
    this.summary,
    required this.sets,
  });

  factory ParsedWorkout.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final rawDate = json['sessionDate'];
    if (rawDate is String && rawDate.trim().isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate.trim());
    }

    return ParsedWorkout(
      sessionDate: parsedDate,
      name: json['name'] as String?,
      summary: json['summary'] as String?,
      sets: (json['sets'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ParsedSet.fromJson)
          .toList(),
    );
  }
}
