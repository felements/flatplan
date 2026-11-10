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
/// line of the same colour, holding each period's limit flat across the
/// period's whole slot. The chart fills the space its parent gives it and
/// draws no card of its own; the hollow point is filled in the card colour,
/// so put it on a card.
///
/// A click in a period picks the dot there nearest the pointer and reports
/// it to [onPointTap]; the [selected] dot is drawn with a ring.
class StatsLineChart extends StatelessWidget {
  const StatsLineChart({
    super.key,
    required this.chart,
    required this.colors,
    this.selected,
    this.onPointTap,
  });

  final StatsChart chart;

  /// The colour of each line, in the order of [StatsChart.lines].
  final List<Color> colors;

  /// The dot to ring: the index of its line and of its period.
  final ({int line, int period})? selected;

  /// Called with the line and period index of a clicked dot.
  final void Function(int line, int period)? onPointTap;

  /// The least room the left axis labels get, enough for four-figure
  /// amounts.
  static const _minLeftAxisWidth = 56.0;

  /// The gap fl_chart's `SideTitleWidget` leaves between a label and the
  /// plot.
  static const _titleSpace = 8.0;

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
    final leftAxisWidth = _leftAxisWidth(context, format, labelStyle, bounds);

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
              reservedSize: leftAxisWidth,
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
          touchCallback: (event, response) {
            final onTap = onPointTap;
            if (onTap == null || event is! FlTapUpEvent || response == null) {
              return;
            }
            final period = _periodOf(response.lineBarSpots ?? const []);
            if (period == null) return;
            final line = nearestLineAt(
              chart,
              period,
              response.touchChartCoordinate.dy,
            );
            if (line != null) onTap(line, period);
          },
          mouseCursorResolver: (event, response) =>
              onPointTap != null &&
                  _periodOf(response?.lineBarSpots ?? const []) != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              // The limit has nothing to mark, and its ends lie half a slot
              // out, between two periods.
              if (bar.isStepLineChart)
                null
              else
                TouchedSpotIndicatorData(
                  FlLine(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                  FlDotData(
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
              getDotPainter: (spot, percent, bar, index) => _ringIfSelected(
                FlDotCirclePainter(radius: _dotRadius, color: color),
                i,
                spot,
                color,
              ),
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
              getDotPainter: (spot, percent, bar, index) => _ringIfSelected(
                FlDotCirclePainter(
                  radius: _dotRadius,
                  color: cardColor,
                  strokeColor: color,
                  strokeWidth: _lineWidth,
                ),
                i,
                spot,
                color,
              ),
            ),
          ),
        );
      }

      final limits = line.limits;
      if (limits != null) {
        bars.add(
          LineChartBarData(
            spots: _limitSpots(limits),
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

  /// Room for the left axis labels: the widest label the axis can show, plus
  /// the gap before the plot, so a label never wraps onto a second line.
  ///
  /// No tick lies beyond the axis ends, so no label has more digits than
  /// theirs. Digits differ in width ("200,000" is wider than "275,000" in
  /// Outfit), so each end is measured with all its digits set to the widest.
  static double _leftAxisWidth(
    BuildContext context,
    NumberFormat format,
    TextStyle? style,
    ({double minY, double maxY}) bounds,
  ) {
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    final resolved = DefaultTextStyle.of(context).style.merge(style);
    double widthOf(String text) {
      painter
        ..text = TextSpan(text: text, style: resolved)
        ..layout();
      return painter.width;
    }

    var widestDigit = '0';
    var digitWidth = 0.0;
    for (var d = 0; d <= 9; d++) {
      final width = widthOf('$d');
      if (width > digitWidth) {
        widestDigit = '$d';
        digitWidth = width;
      }
    }
    var widest = 0.0;
    for (final end in [bounds.minY, bounds.maxY]) {
      final label = format
          .format(end.truncateToDouble())
          .replaceAll(RegExp(r'\d'), widestDigit);
      widest = math.max(widest, widthOf(label));
    }
    painter.dispose();
    // A pixel or two of slack against rounding in the label's own layout.
    return math.max(_minLeftAxisWidth, widest.ceilToDouble() + _titleSpace + 2);
  }

  /// [dot] with a ring around it when it is the [selected] dot: line [line]
  /// at [spot]'s period.
  FlDotPainter _ringIfSelected(
    FlDotPainter dot,
    int line,
    FlSpot spot,
    Color color,
  ) {
    final picked = selected;
    if (picked == null || picked.line != line || spot.x != picked.period) {
      return dot;
    }
    return _RingedDotPainter(dot, color);
  }

  /// The period a touch is in: that of the nearest touched spot at a whole
  /// x. A limit bar's end spots lie half a slot out, between two periods,
  /// and name none.
  static int? _periodOf(List<LineBarSpot> spots) {
    final onPeriod = spots
        .where((spot) => (spot.x - spot.x.roundToDouble()).abs() < 1e-6)
        .firstOrNull;
    return onPeriod?.x.round();
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

  /// The points of the limit bar: each run of periods that have a limit
  /// starts half a slot before its first period and ends half a slot after
  /// its last, so every limit holds flat across its period's whole slot, and
  /// a gap separates runs.
  ///
  /// A run is never a single spot: fl_chart dashes each run on its own, and a
  /// lone spot is a zero-length path that dashes into nothing.
  List<FlSpot> _limitSpots(List<double?> limits) {
    final spots = <FlSpot>[];
    for (var i = 0; i < limits.length; i++) {
      final limit = limits[i];
      if (limit == null) continue;
      final startsRun = i == 0 || limits[i - 1] == null;
      final endsRun = i == limits.length - 1 || limits[i + 1] == null;
      if (startsRun) {
        if (spots.isNotEmpty) spots.add(FlSpot.nullSpot);
        spots.add(FlSpot(i - 0.5, limit));
      }
      spots.add(FlSpot(i.toDouble(), limit));
      if (endsRun) spots.add(FlSpot(i + 0.5, limit));
    }
    return spots;
  }

  /// One tooltip for the whole period: fl_chart hands over a touched spot per
  /// bar, and only the first gets the text, the rest none.
  ///
  /// The period is the one [_periodOf] finds; touching none gives no tooltip.
  List<LineTooltipItem?> _tooltipItems(
    ThemeData theme,
    NumberFormat format,
    List<LineBarSpot> spots,
  ) {
    final index = _periodOf(spots);
    if (index == null) return [for (final _ in spots) null];
    final scheme = theme.colorScheme;
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

/// A chart dot with a ring around it, marking the dot the user picked.
class _RingedDotPainter extends FlDotPainter {
  const _RingedDotPainter(this.dot, this.color);

  /// The dot as drawn when not picked.
  final FlDotPainter dot;
  final Color color;

  static const _radius = 7.0;
  static const _width = 2.0;

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    dot.draw(canvas, spot, offsetInCanvas);
    canvas.drawCircle(
      offsetInCanvas,
      _radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _width,
    );
  }

  @override
  Size getSize(FlSpot spot) => const Size.fromRadius(_radius + _width / 2);

  @override
  Color get mainColor => dot.mainColor;

  // The ring comes and goes at once; there is nothing to animate.
  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;

  @override
  List<Object?> get props => [dot, color];
}
