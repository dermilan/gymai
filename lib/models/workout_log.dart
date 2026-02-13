import 'set_log.dart';

class WorkoutLog {
  final String? id;
  final String name;
  final String? summary;
  final String? aiComment;
  final DateTime date;
  final List<SetLog> sets;
  final int? durationMinutes;

  const WorkoutLog({
    this.id,
    required this.name,
    this.summary,
    this.aiComment,
    required this.date,
    required this.sets,
    this.durationMinutes,
  });

  double get totalVolume =>
      sets.fold(0, (total, set) => total + set.volume);

  String get effectiveId =>
      (id != null && id!.isNotEmpty)
          ? id!
          : '${date.microsecondsSinceEpoch}-$name';

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    return WorkoutLog(
      id: json['id'] as String?,
      name: json['name'] as String,
      summary: json['summary'] as String?,
      aiComment: json['aiComment'] as String?,
      date: DateTime.parse(json['date'] as String),
      sets: (json['sets'] as List)
          .map((e) => SetLog.fromJson(e as Map<String, dynamic>))
          .toList(),
      durationMinutes: json['durationMinutes'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'summary': summary,
        'aiComment': aiComment,
        'date': date.toIso8601String(),
        'sets': sets.map((set) => set.toJson()).toList(),
        'durationMinutes': durationMinutes,
      };
}
