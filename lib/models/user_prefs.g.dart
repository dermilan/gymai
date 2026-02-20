// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_prefs.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserPrefsImpl _$$UserPrefsImplFromJson(Map<String, dynamic> json) =>
    _$UserPrefsImpl(
      goal: json['goal'] as String? ?? 'Hypertrophy',
      daysPerWeek: (json['daysPerWeek'] as num?)?.toInt() ?? 3,
      equipment: json['equipment'] as String? ?? 'Full gym',
      injuries: json['injuries'] as String? ?? 'None',
      sessionDurationMinutes:
          (json['sessionDurationMinutes'] as num?)?.toInt() ?? 60,
      includeWarmUp: json['includeWarmUp'] as bool? ?? true,
      includeCoolDown: json['includeCoolDown'] as bool? ?? true,
      persona: json['persona'] as String? ?? 'Gym Bro',
      preferredName: json['preferredName'] as String? ?? 'Champ',
      weightUnit:
          $enumDecodeNullable(_$WeightUnitEnumMap, json['weightUnit']) ??
              WeightUnit.kg,
    );

Map<String, dynamic> _$$UserPrefsImplToJson(_$UserPrefsImpl instance) =>
    <String, dynamic>{
      'goal': instance.goal,
      'daysPerWeek': instance.daysPerWeek,
      'equipment': instance.equipment,
      'injuries': instance.injuries,
      'sessionDurationMinutes': instance.sessionDurationMinutes,
      'includeWarmUp': instance.includeWarmUp,
      'includeCoolDown': instance.includeCoolDown,
      'persona': instance.persona,
      'preferredName': instance.preferredName,
      'weightUnit': _$WeightUnitEnumMap[instance.weightUnit]!,
    };

const _$WeightUnitEnumMap = {
  WeightUnit.kg: 'kg',
  WeightUnit.lbs: 'lbs',
};
