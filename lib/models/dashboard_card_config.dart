import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_card_config.freezed.dart';
part 'dashboard_card_config.g.dart';

/// Identifiers for every customisable dashboard card.
enum DashboardCardId {
  goalProgress,
  weeklyVolume,
  lastSession,
  volTrend,
  weeklyFocus,
  streak,
  personalRecords,
  exerciseSplit,
  favoriteExercises,
  restDays,
  volumeTrendChart,
}

/// Holds user-facing metadata for each card type.
class _CardMeta {
  final String label;
  final IconData icon;
  const _CardMeta(this.label, this.icon);
}

const _meta = <DashboardCardId, _CardMeta>{
  DashboardCardId.goalProgress:
      _CardMeta('Goal Progress', Icons.calendar_today_rounded),
  DashboardCardId.weeklyVolume:
      _CardMeta('Weekly Volume', Icons.local_fire_department_rounded),
  DashboardCardId.lastSession:
      _CardMeta('Last Session', Icons.history_rounded),
  DashboardCardId.volTrend:
      _CardMeta('Volume Trend (stat)', Icons.trending_up_rounded),
  DashboardCardId.weeklyFocus:
      _CardMeta('Weekly Focus', Icons.emoji_events_rounded),
  DashboardCardId.streak:
      _CardMeta('Current Streak', Icons.local_fire_department_rounded),
  DashboardCardId.personalRecords:
      _CardMeta('Personal Records', Icons.emoji_events_rounded),
  DashboardCardId.exerciseSplit:
      _CardMeta('Exercise Split', Icons.pie_chart_rounded),
  DashboardCardId.favoriteExercises:
      _CardMeta('Favorite Exercises', Icons.favorite_rounded),
  DashboardCardId.restDays:
      _CardMeta('Rest Days Insight', Icons.bedtime_rounded),
  DashboardCardId.volumeTrendChart:
      _CardMeta('Volume Trend (chart)', Icons.show_chart_rounded),
};

// ignore_for_file: invalid_annotation_target

@freezed
class DashboardCardConfig with _$DashboardCardConfig {
  const DashboardCardConfig._();

  const factory DashboardCardConfig({
    @Default(DashboardCardId.goalProgress)
    @JsonKey(unknownEnumValue: DashboardCardId.goalProgress)
    DashboardCardId id,
    @Default(true) bool visible,
  }) = _DashboardCardConfig;

  factory DashboardCardConfig.fromJson(Map<String, dynamic> json) =>
      _$DashboardCardConfigFromJson(json);

  @override
  Map<String, dynamic> toJson();

  String get label => _meta[id]!.label;
  IconData get icon => _meta[id]!.icon;

  bool get isCompact {
    switch (id) {
      case DashboardCardId.goalProgress:
      case DashboardCardId.weeklyVolume:
      case DashboardCardId.lastSession:
      case DashboardCardId.volTrend:
        return true;
      default:
        return false;
    }
  }

  /// The default layout with all cards visible.
  static List<DashboardCardConfig> defaultLayout() {
    return DashboardCardId.values
        .map((id) => DashboardCardConfig(id: id))
        .toList();
  }

  /// Merges a saved layout with the full enum list so new cards are appended.
  static List<DashboardCardConfig> mergeWithDefaults(
      List<DashboardCardConfig> saved) {
    final seenIds = saved.map((c) => c.id).toSet();
    final missing = DashboardCardId.values
        .where((id) => !seenIds.contains(id))
        .map((id) => DashboardCardConfig(id: id));
    return [...saved, ...missing];
  }
}
