import 'set_log.dart';

class WorkoutLog {
  final String? id;
  final String name;
  final DateTime date;
  final List<SetLog> sets;
  final int? durationMinutes;

  const WorkoutLog({
    this.id,
    required this.name,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date.toIso8601String(),
        'sets': sets.map((set) => set.toJson()).toList(),
        'durationMinutes': durationMinutes,
      };
}
