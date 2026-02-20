import '../models/user_prefs.dart';

/// Conversion factor: 1 kg = 2.20462 lbs
const double _kgToLbs = 2.20462;
const double _lbsToKg = 1 / _kgToLbs;

/// Convert weight from kg (internal) to display unit
double toDisplayWeight(double kg, WeightUnit unit) {
  if (unit == WeightUnit.lbs) {
    return kg * _kgToLbs;
  }
  return kg;
}

/// Convert weight from display unit to kg (internal)
double toInternalWeight(double value, WeightUnit unit) {
  if (unit == WeightUnit.lbs) {
    return value * _lbsToKg;
  }
  return value;
}

/// Format weight for display with unit label
String formatWeight(double kg, WeightUnit unit, {int decimals = 1}) {
  final displayValue = toDisplayWeight(kg, unit);
  final unitLabel = unit == WeightUnit.lbs ? 'lbs' : 'kg';
  return '${displayValue.toStringAsFixed(decimals)} $unitLabel';
}

/// Format weight for display without unit label (for inputs)
String formatWeightValue(double kg, WeightUnit unit, {int decimals = 1}) {
  final displayValue = toDisplayWeight(kg, unit);
  return displayValue.toStringAsFixed(decimals);
}

/// Get unit label string
String weightUnitLabel(WeightUnit unit) {
  return unit == WeightUnit.lbs ? 'lbs' : 'kg';
}
