// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_card_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DashboardCardConfigImpl _$$DashboardCardConfigImplFromJson(
        Map<String, dynamic> json) =>
    _$DashboardCardConfigImpl(
      id: $enumDecodeNullable(_$DashboardCardIdEnumMap, json['id'],
              unknownValue: DashboardCardId.goalProgress) ??
          DashboardCardId.goalProgress,
      visible: json['visible'] as bool? ?? true,
    );

Map<String, dynamic> _$$DashboardCardConfigImplToJson(
        _$DashboardCardConfigImpl instance) =>
    <String, dynamic>{
      'id': _$DashboardCardIdEnumMap[instance.id]!,
      'visible': instance.visible,
    };

const _$DashboardCardIdEnumMap = {
  DashboardCardId.goalProgress: 'goalProgress',
  DashboardCardId.weeklyVolume: 'weeklyVolume',
  DashboardCardId.lastSession: 'lastSession',
  DashboardCardId.volTrend: 'volTrend',
  DashboardCardId.weeklyFocus: 'weeklyFocus',
  DashboardCardId.streak: 'streak',
  DashboardCardId.personalRecords: 'personalRecords',
  DashboardCardId.exerciseSplit: 'exerciseSplit',
  DashboardCardId.favoriteExercises: 'favoriteExercises',
  DashboardCardId.restDays: 'restDays',
  DashboardCardId.volumeTrendChart: 'volumeTrendChart',
};
