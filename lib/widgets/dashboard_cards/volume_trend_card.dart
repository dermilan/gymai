import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/user_prefs.dart';
import '../../utils/weight_utils.dart';

class VolumeDayPoint {
  final DateTime date;
  final double volume;
  const VolumeDayPoint({required this.date, required this.volume});
}

class VolumeTrendCard extends StatelessWidget {
  final List<VolumeDayPoint> dataPoints;
  final WeightUnit weightUnit;
  const VolumeTrendCard({super.key, required this.dataPoints, required this.weightUnit});

  static const _accentStart = Color(0xFF00BFA6);
  static const _accentEnd = Color(0xFF7C4DFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentStart.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.show_chart_rounded,
                    color: _accentStart, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Volume Trend',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Total tonnage per session (Sets × Reps × Weight)',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // chart or empty state
          if (dataPoints.length < 2)
            const SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  'Log at least 2 sessions to see the trend',
                  style: TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: _buildChart(),
            ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    // Build spots using the index as X, volume as Y.
    final spots = dataPoints
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.volume))
        .toList();

    final maxY =
        spots.map((s) => s.y).reduce(math.max);
    final topY = (maxY * 1.15).ceilToDouble(); // 15% headroom

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: topY > 0 ? topY : 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: topY > 0 ? topY / 4 : 25,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, _) {
                String label;
                if (value >= 1000) {
                  label = '${(value / 1000).toStringAsFixed(1)}k';
                } else {
                  label = value.toInt().toString();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.white38),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: _bottomInterval(),
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= dataPoints.length) {
                  return const SizedBox.shrink();
                }
                final d = dataPoints[idx].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${d.day}/${d.month}',
                    style: const TextStyle(
                        fontSize: 10, color: Colors.white38),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF2A2A3C),
            getTooltipItems: (spots) => spots.map((s) {
              final pt = dataPoints[s.spotIndex];
              final d = pt.date;
              final vol = pt.volume >= 1000
                  ? '${(pt.volume / 1000).toStringAsFixed(1)}k'
                  : '${pt.volume.toInt()}';
              return LineTooltipItem(
                '$vol ${weightUnitLabel(weightUnit)}\n${d.day}/${d.month}/${d.year}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            gradient: const LinearGradient(
              colors: [_accentStart, _accentEnd],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: Color.lerp(
                    _accentStart,
                    _accentEnd,
                    spot.x / (spots.length - 1).clamp(1, double.infinity))!,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  _accentStart.withValues(alpha: 0.25),
                  _accentEnd.withValues(alpha: 0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _bottomInterval() {
    final n = dataPoints.length;
    if (n <= 6) return 1;
    if (n <= 12) return 2;
    if (n <= 24) return 4;
    return (n / 6).ceilToDouble();
  }
}
