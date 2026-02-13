class UserPrefs {
  final String goal;
  final int daysPerWeek;
  final String equipment;
  final String injuries;
  final int sessionDurationMinutes;
  final bool includeWarmUp;
  final bool includeCoolDown;
  final String apiKey;
  final String model;
  final String persona;
  final String preferredName;

  const UserPrefs({
    required this.goal,
    required this.daysPerWeek,
    required this.equipment,
    required this.injuries,
    this.sessionDurationMinutes = 60,
    this.includeWarmUp = true,
    this.includeCoolDown = true,
    this.apiKey = '',
    this.model = 'x-ai/grok-4.1-fast',
    this.persona = 'Gym Bro',
    this.preferredName = 'Champ',
  });

  factory UserPrefs.empty() {
    return const UserPrefs(
      goal: 'Hypertrophy',
      daysPerWeek: 3,
      equipment: 'Full gym',
      injuries: 'None',
      sessionDurationMinutes: 60,
      includeWarmUp: true,
      includeCoolDown: true,
      persona: 'Gym Bro',
      preferredName: 'Champ',
    );
  }

  bool get hasApiKey => apiKey.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'goal': goal,
        'daysPerWeek': daysPerWeek,
        'equipment': equipment,
        'injuries': injuries,
        'sessionDurationMinutes': sessionDurationMinutes,
        'includeWarmUp': includeWarmUp,
        'includeCoolDown': includeCoolDown,
        'apiKey': apiKey,
        'model': model,
        'persona': persona,
        'preferredName': preferredName,
      };

  factory UserPrefs.fromJson(Map<String, dynamic> json) {
    return UserPrefs(
      goal: (json['goal'] ?? 'Hypertrophy').toString(),
      daysPerWeek: int.tryParse((json['daysPerWeek'] ?? '3').toString()) ?? 3,
      equipment: (json['equipment'] ?? 'Full gym').toString(),
      injuries: (json['injuries'] ?? 'None').toString(),
        sessionDurationMinutes:
          int.tryParse((json['sessionDurationMinutes'] ?? '60').toString()) ??
            60,
        includeWarmUp: json['includeWarmUp'] == null
          ? true
          : json['includeWarmUp'] == true,
        includeCoolDown: json['includeCoolDown'] == null
          ? true
          : json['includeCoolDown'] == true,
      apiKey: (json['apiKey'] ?? '').toString(),
      model: (json['model'] ?? 'x-ai/grok-4.1-fast').toString(),
      persona: (json['persona'] ?? 'Gym Bro').toString(),
      preferredName: (json['preferredName'] ?? 'Champ').toString(),
    );
  }
}
