import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../logic/stats_series.dart';
import 'summary_card.dart';

/// The colours of the Stats chart lines other than All's, in tick order.
///
/// Each is readable (at least 3:1 contrast) on the dark card (`#1E1E2E`) and
/// on the light one, and the order keeps neighbouring colours apart for
/// colour-blind readers. Teal and gold belong to All, and coral is the error
/// colour, so none of them is here.
const statsPalette = <Color>[
  Color(0xFF388CF0), // blue
  Color(0xFFC25485), // rose
  Color(0xFF5AA04A), // green
  Color(0xFF765DCF), // violet
  Color(0xFF00A0C1), // cyan
  Color(0xFF949300), // olive
  Color(0xFFA55095), // orchid
  Color(0xFF007FC8), // azure
];

/// One colour per line of [chart].
///
/// All's spent line is teal (`scheme.secondary`) and its earned line gold
/// (`scheme.primary`). Every other line takes the next [statsPalette] colour,
/// wrapping after the eighth.
List<Color> statsLineColors(StatsChart chart, ColorScheme scheme) {
  final colors = <Color>[];
  var next = 0;
  for (final line in chart.lines) {
    if (line.subject == StatsSubject.all) {
      colors.add(
        line.role == StatsLineRole.earned ? scheme.primary : scheme.secondary,
      );
    } else {
      colors.add(statsPalette[next % statsPalette.length]);
      next++;
    }
  }
  return colors;
}

/// How many periods apart the x labels are, so they do not overlap: every
/// period up to twelve, then every second, third and so on.
int bottomLabelInterval(int periodCount) =>
    math.max(1, (periodCount / 12).ceil());

/// The y range of [chart]: from 0 (or from below it, for a negative figure)
/// to above the highest value or limit, with a tenth of headroom either way.
///
/// With nothing above zero the top is 1, so the axis never collapses.
({double minY, double maxY}) statsYBounds(StatsChart chart) {
  double? lowest;
  double? highest;
  for (final line in chart.lines) {
    for (final figure in [...line.values, ...?line.limits]) {
      if (figure == null) continue;
      lowest = lowest == null ? figure : math.min(lowest, figure);
      highest = highest == null ? figure : math.max(highest, figure);
    }
  }
  return (
    minY: lowest != null && lowest < 0 ? lowest * 1.1 : 0,
    maxY: highest != null && highest > 0 ? highest * 1.1 : 1,
  );
}

/// A line chart of [chart], one coloured line per [StatsLine].
///
/// Each line is a solid run up to the period in progress, then a dashed
/// stretch into that period whose point is hollow: its figure is still
/// moving. A line with budget limits also gets a stepped, dashed, fainter
/// line of the same colour. The chart fills the space its parent gives it and
/// draws no card of its own; the hollow point is filled in the card colour,
/// so put it on a card.
class StatsLineChart extends StatelessWidget {
  const StatsLineChart({super.key, required this.chart, required this.colors});

  final StatsChart chart;

  /// The colour of each line, in the order of [StatsChart.lines].
  final List<Color> colors;

  static const _lineWidth = 2.0;
  static const _dotRadius = 3.0;
  static const _limitAlpha = 0.55;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cardColor = summaryCardDecoration(context).color!;
    final format = NumberFormat.decimalPatternDigits(decimalDigits: 0);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final count = chart.periods.length;
    final labelInterval = bottomLabelInterval(count);
    final bounds = statsYBounds(chart);

    return LineChart(
      LineChartData(
        minX: -0.5,
        maxX: count - 0.5,
        minY: bounds.minY,
        maxY: bounds.maxY,
        lineBarsData: _bars(cardColor),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if ((value - index).abs() > 1e-6 ||
                    index < 0 ||
                    index >= count ||
                    index % labelInterval != 0) {
                  return const SizedBox.shrink();
                }
                final start = chart.periods[index].startDate;
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    DateFormat('MMM yy').format(start),
                    style: labelStyle,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) {
                // The axis ends are labelled too, which would crowd the
                // ticks: keep only the labels that fall on a tick. Amounts
                // show without decimals, so a fractional tick (0.2 on a 0 to
                // 1 axis) would repeat its neighbour's label: keep whole
                // values only.
                final ticks = value / meta.appliedInterval;
                if ((ticks - ticks.roundToDouble()).abs() > 1e-6 ||
                    (value - value.roundToDouble()).abs() > 1e-6) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(format.format(value), style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  strokeWidth: 1,
                ),
                FlDotData(
                  // The limit line has no point to highlight.
                  show: !bar.isStepLineChart,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                        radius: _dotRadius + 2,
                        color: bar.color ?? scheme.primary,
                        strokeColor: cardColor,
                        strokeWidth: 2,
                      ),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            maxContentWidth: 260,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipBorderRadius: BorderRadius.circular(12),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            tooltipBorder: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
              width: 0.5,
            ),
            getTooltipColor: (_) => scheme.surfaceContainerHigh,
            getTooltipItems: (spots) => _tooltipItems(theme, format, spots),
          ),
        ),
      ),
    );
  }

  /// The bars of every line, in order: the solid run, the dashed stretch into
  /// the period in progress and the limit.
  List<LineChartBarData> _bars(Color cardColor) {
    final count = chart.periods.length;
    final inProgress = chart.inProgressIndex;
    final solidEnd = inProgress ?? count;
    final bars = <LineChartBarData>[];

    for (var i = 0; i < chart.lines.length; i++) {
      final line = chart.lines[i];
      final color = colors[i];

      if (solidEnd > 0) {
        bars.add(
          LineChartBarData(
            spots: _spots(line.values, 0, solidEnd),
            color: color,
            barWidth: _lineWidth,
            isStrokeCapRound: true,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(radius: _dotRadius, color: color),
            ),
          ),
        );
      }

      if (inProgress != null) {
        bars.add(
          LineChartBarData(
            spots: _spots(
              line.values,
              math.max(0, inProgress - 1),
              inProgress + 1,
            ),
            color: color,
            barWidth: _lineWidth,
            dashArray: const [5, 4],
            dotData: FlDotData(
              // Only the period in progress: the solid run draws the other end.
              checkToShowDot: (spot, bar) => spot.x == inProgress,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: _dotRadius,
                color: cardColor,
                strokeColor: color,
                strokeWidth: _lineWidth,
              ),
            ),
          ),
        );
      }

      final limits = line.limits;
      if (limits != null) {
        bars.add(
          LineChartBarData(
            spots: _spots(limits, 0, count),
            color: color.withValues(alpha: _limitAlpha),
            barWidth: _lineWidth,
            dashArray: const [6, 4],
            isStepLineChart: true,
            lineChartStepData: const LineChartStepData(
              stepDirection: LineChartStepData.stepDirectionMiddle,
            ),
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }
    return bars;
  }

  /// The points of [figures] from index [from] up to, not including, [to]; a
  /// gap stays a gap.
  List<FlSpot> _spots(List<double?> figures, int from, int to) => [
    for (var i = from; i < to; i++)
      if (figures[i] case final figure?)
        FlSpot(i.toDouble(), figure)
      else
        FlSpot.nullSpot,
  ];

  /// One tooltip for the whole period: fl_chart hands over a touched spot per
  /// bar, and only the first gets the text, the rest none.
  List<LineTooltipItem?> _tooltipItems(
    ThemeData theme,
    NumberFormat format,
    List<LineBarSpot> spots,
  ) {
    if (spots.isEmpty) return const [];
    final scheme = theme.colorScheme;
    final index = spots.first.x.round();
    final base = theme.textTheme.bodySmall ?? const TextStyle();
    final rows = <TextSpan>[];
    for (final row in tooltipRows(chart, index)) {
      final color = colors[chart.lines.indexOf(row.line)];
      rows.add(
        TextSpan(
          style: base.copyWith(
            fontWeight: FontWeight.normal,
            color: scheme.onSurface,
          ),
          children: [
            const TextSpan(text: '\n'),
            TextSpan(
              text: row.line.label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            TextSpan(text: '  ${format.format(row.value)}'),
            if (row.limit case final limit?)
              TextSpan(
                text: '\nlimit  ${format.format(limit)}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      );
    }
    final item = LineTooltipItem(
      chart.periods[index].name,
      base.copyWith(fontWeight: FontWeight.bold, color: scheme.onSurface),
      textAlign: TextAlign.left,
      children: rows,
    );
    return [item, for (var i = 1; i < spots.length; i++) null];
  }
}
