class UserPrefs {
  final String goal;
  final int daysPerWeek;
  final String equipment;
  final String injuries;
  final String apiKey;
  final String model;

  const UserPrefs({
    required this.goal,
    required this.daysPerWeek,
    required this.equipment,
    required this.injuries,
    this.apiKey = '',
    this.model = 'x-ai/grok-4.1-fast',
  });

  factory UserPrefs.empty() {
    return const UserPrefs(
      goal: 'Hypertrophy',
      daysPerWeek: 3,
      equipment: 'Full gym',
      injuries: 'None',
    );
  }

  bool get hasApiKey => apiKey.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'goal': goal,
        'daysPerWeek': daysPerWeek,
        'equipment': equipment,
        'injuries': injuries,
        'apiKey': apiKey,
        'model': model,
      };

  factory UserPrefs.fromJson(Map<String, dynamic> json) {
    return UserPrefs(
      goal: (json['goal'] ?? 'Hypertrophy').toString(),
      daysPerWeek: int.tryParse((json['daysPerWeek'] ?? '3').toString()) ?? 3,
      equipment: (json['equipment'] ?? 'Full gym').toString(),
      injuries: (json['injuries'] ?? 'None').toString(),
      apiKey: (json['apiKey'] ?? '').toString(),
      model: (json['model'] ?? 'x-ai/grok-4.1-fast').toString(),
    );
  }
}
