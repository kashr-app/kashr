import 'package:decimal/decimal.dart';
import 'package:finanalyzer/analytics/cubit/analytics_cubit.dart';
import 'package:finanalyzer/analytics/cubit/analytics_state.dart';
import 'package:finanalyzer/core/color_utils.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AnalyticsChart extends StatelessWidget {
  const AnalyticsChart({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnalyticsCubit, AnalyticsState>(
      builder: (context, state) {
        if (state.dataSummaries.isEmpty) {
          return const SizedBox(
            height: 300,
            child: Center(
              child: Text('No data available for the selected period'),
            ),
          );
        }

        final chartData = _prepareChartData(state);

        return SizedBox(
          height: 300,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 16),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 500,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= chartData.months.length) {
                          return const SizedBox.shrink();
                        }
                        final month = chartData.months[index];
                        final parts = month.split('-');
                        if (parts.length != 2) return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${parts[1]}/${parts[0].substring(2)}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          Currency.EUR.format(Decimal.parse(value.toString())),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                lineBarsData: chartData.lines,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final tagName = chartData.tagNames[spot.barIndex];
                        final amount = Decimal.parse(spot.y.toString());
                        return LineTooltipItem(
                          '$tagName\n${Currency.EUR.format(amount)}',
                          TextStyle(
                            color: spot.bar.color,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _ChartData _prepareChartData(AnalyticsState state) {
    final months = state.dataSummaries.keys.toList()..sort();

    final tagColorMap = <String, Color>{};
    final tagDataMap = <String, List<FlSpot>>{};

    for (var i = 0; i < months.length; i++) {
      final month = months[i];
      final summaries = state.dataSummaries[month] ?? [];

      for (final summary in summaries) {
        final tagName = summary.tag.name;
        final tagId = summary.tag.id?.uuid ?? '';

        if (!state.selectedTagIds.any((id) => id.uuid == tagId)) {
          continue;
        }

        tagColorMap.putIfAbsent(
          tagName,
          () =>
              ColorUtils.parseColor(summary.tag.color) ??
              _generateColor(tagName),
        );

        tagDataMap.putIfAbsent(tagName, () => []);
        tagDataMap[tagName]!.add(
          FlSpot(i.toDouble(), summary.totalAmount.toDouble()),
        );
      }
    }

    final lines = <LineChartBarData>[];
    final tagNames = <String>[];

    for (final entry in tagDataMap.entries) {
      tagNames.add(entry.key);
      lines.add(
        LineChartBarData(
          spots: entry.value,
          isCurved: true,
          color: tagColorMap[entry.key],
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: barData.color ?? Colors.blue,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    return _ChartData(months: months, lines: lines, tagNames: tagNames);
  }

  Color _generateColor(String tagName) {
    final hash = tagName.hashCode;
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();
  }
}

class _ChartData {
  final List<String> months;
  final List<LineChartBarData> lines;
  final List<String> tagNames;

  _ChartData({
    required this.months,
    required this.lines,
    required this.tagNames,
  });
}
