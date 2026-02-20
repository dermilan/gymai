import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_prefs.freezed.dart';
part 'user_prefs.g.dart';

/// Weight unit for display and input
enum WeightUnit { kg, lbs }

@freezed
class UserPrefs with _$UserPrefs {
  const factory UserPrefs({
    @Default('Hypertrophy') String goal,
    @Default(3) int daysPerWeek,
    @Default('Full gym') String equipment,
    @Default('None') String injuries,
    @Default(60) int sessionDurationMinutes,
    @Default(true) bool includeWarmUp,
    @Default(true) bool includeCoolDown,
    @Default('Gym Bro') String persona,
    @Default('Champ') String preferredName,
    @Default(WeightUnit.kg) WeightUnit weightUnit,
  }) = _UserPrefs;

  factory UserPrefs.empty() => const UserPrefs();

  factory UserPrefs.fromJson(Map<String, dynamic> json) =>
      _$UserPrefsFromJson(json);
}
