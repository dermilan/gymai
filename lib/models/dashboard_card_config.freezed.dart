// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard_card_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DashboardCardConfig _$DashboardCardConfigFromJson(Map<String, dynamic> json) {
  return _DashboardCardConfig.fromJson(json);
}

/// @nodoc
mixin _$DashboardCardConfig {
  @JsonKey(unknownEnumValue: DashboardCardId.goalProgress)
  DashboardCardId get id => throw _privateConstructorUsedError;
  bool get visible => throw _privateConstructorUsedError;

  /// Serializes this DashboardCardConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DashboardCardConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DashboardCardConfigCopyWith<DashboardCardConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardCardConfigCopyWith<$Res> {
  factory $DashboardCardConfigCopyWith(
          DashboardCardConfig value, $Res Function(DashboardCardConfig) then) =
      _$DashboardCardConfigCopyWithImpl<$Res, DashboardCardConfig>;
  @useResult
  $Res call(
      {@JsonKey(unknownEnumValue: DashboardCardId.goalProgress)
      DashboardCardId id,
      bool visible});
}

/// @nodoc
class _$DashboardCardConfigCopyWithImpl<$Res, $Val extends DashboardCardConfig>
    implements $DashboardCardConfigCopyWith<$Res> {
  _$DashboardCardConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DashboardCardConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? visible = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as DashboardCardId,
      visible: null == visible
          ? _value.visible
          : visible // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DashboardCardConfigImplCopyWith<$Res>
    implements $DashboardCardConfigCopyWith<$Res> {
  factory _$$DashboardCardConfigImplCopyWith(_$DashboardCardConfigImpl value,
          $Res Function(_$DashboardCardConfigImpl) then) =
      __$$DashboardCardConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(unknownEnumValue: DashboardCardId.goalProgress)
      DashboardCardId id,
      bool visible});
}

/// @nodoc
class __$$DashboardCardConfigImplCopyWithImpl<$Res>
    extends _$DashboardCardConfigCopyWithImpl<$Res, _$DashboardCardConfigImpl>
    implements _$$DashboardCardConfigImplCopyWith<$Res> {
  __$$DashboardCardConfigImplCopyWithImpl(_$DashboardCardConfigImpl _value,
      $Res Function(_$DashboardCardConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of DashboardCardConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? visible = null,
  }) {
    return _then(_$DashboardCardConfigImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as DashboardCardId,
      visible: null == visible
          ? _value.visible
          : visible // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardCardConfigImpl extends _DashboardCardConfig {
  const _$DashboardCardConfigImpl(
      {@JsonKey(unknownEnumValue: DashboardCardId.goalProgress)
      this.id = DashboardCardId.goalProgress,
      this.visible = true})
      : super._();

  factory _$DashboardCardConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardCardConfigImplFromJson(json);

  @override
  @JsonKey(unknownEnumValue: DashboardCardId.goalProgress)
  final DashboardCardId id;
  @override
  @JsonKey()
  final bool visible;

  @override
  String toString() {
    return 'DashboardCardConfig(id: $id, visible: $visible)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardCardConfigImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.visible, visible) || other.visible == visible));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, visible);

  /// Create a copy of DashboardCardConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardCardConfigImplCopyWith<_$DashboardCardConfigImpl> get copyWith =>
      __$$DashboardCardConfigImplCopyWithImpl<_$DashboardCardConfigImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardCardConfigImplToJson(
      this,
    );
  }
}

abstract class _DashboardCardConfig extends DashboardCardConfig {
  const factory _DashboardCardConfig(
      {@JsonKey(unknownEnumValue: DashboardCardId.goalProgress)
      final DashboardCardId id,
      final bool visible}) = _$DashboardCardConfigImpl;
  const _DashboardCardConfig._() : super._();

  factory _DashboardCardConfig.fromJson(Map<String, dynamic> json) =
      _$DashboardCardConfigImpl.fromJson;

  @override
  @JsonKey(unknownEnumValue: DashboardCardId.goalProgress)
  DashboardCardId get id;
  @override
  bool get visible;

  /// Create a copy of DashboardCardConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardCardConfigImplCopyWith<_$DashboardCardConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
