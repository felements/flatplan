import 'package:fl_chart/fl_chart.dart';
import 'package:flatplan/src/app_theme.dart';
import 'package:flatplan/src/components/stats_line_chart.dart';
import 'package:flatplan/src/logic/stats_series.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'support/stats_fixtures.dart';

/// [count] periods starting on the fifth of consecutive months from January.
List<Period> _periods(int count) => [
  for (var i = 0; i < count; i++) period('p$i', DateTime(2026, 1 + i, 5), []),
];

StatsLine _line(
  String name,
  List<double?> values, {
  List<double?>? limits,
  bool income = false,
}) => StatsLine(
  subject: StatsSubject.category(name, income: income),
  role: StatsLineRole.value,
  values: values,
  limits: limits,
);

StatsChart _chart(List<StatsLine> lines, {int? inProgress, int? periods}) =>
    StatsChart(
      periods: _periods(periods ?? lines.first.values.length),
      lines: lines,
      inProgressIndex: inProgress,
    );

const _colors = [Color(0xFF388CF0), Color(0xFFC25485)];

Future<void> _pump(
  WidgetTester tester,
  StatsChart chart, {
  ThemeData? theme,
  double width = 800,
  ({int line, int period})? selected,
  void Function(int line, int period)? onPointTap,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme ?? AppTheme.darkTheme,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 300,
          child: StatsLineChart(
            chart: chart,
            colors: _colors,
            selected: selected,
            onPointTap: onPointTap,
          ),
        ),
      ),
    ),
  ),
);

/// The left axis labels on screen: whole-number texts, which the period
/// labels ('Jan 26') are not.
List<String> _leftLabels(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    if (RegExp(r'^-?[\d,]+$').hasMatch(text.data ?? '')) text.data!,
];

LineChartData _data(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

/// How many pixels on screen are clearly blue, the colour of the first line.
/// Nothing else in the chart is: the text, grid and background are grey.
Future<int> _bluePixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData();
    var count = 0;
    for (var i = 0; i < data!.lengthInBytes; i += 4) {
      final red = data.getUint8(i);
      final blue = data.getUint8(i + 2);
      if (blue > red + 40) count++;
    }
    return count;
  }))!;
}

/// The stepped limit bar of the only line on screen: its last bar.
LineChartBarData _limitBar(WidgetTester tester) {
  final bar = _data(tester).lineBarsData.last;
  expect(bar.isStepLineChart, isTrue);
  return bar;
}

/// The stretches [bar] draws: its spots split at the gaps.
List<List<FlSpot>> _runs(LineChartBarData bar) {
  final runs = <List<FlSpot>>[[]];
  for (final spot in bar.spots) {
    if (spot.isNull()) {
      if (runs.last.isNotEmpty) runs.add([]);
    } else {
      runs.last.add(spot);
    }
  }
  if (runs.last.isEmpty) runs.removeLast();
  return runs;
}

/// Where [bar]'s steps fall: the x midway between neighbouring spots that
/// sit at different heights.
List<double> _stepXs(List<FlSpot> run) => [
  for (var i = 1; i < run.length; i++)
    if (run[i].y != run[i - 1].y) (run[i].x + run[i - 1].x) / 2,
];

void main() {
  group('StatsLineChart', () {
    testWidgets('draws a solid run, a dashed stretch into the current period '
        'and a stepped dashed limit', (tester) async {
      final chart = _chart([
        _line('Groceries', [null, 710, 0], limits: [800, 900, 700]),
      ], inProgress: 2);
      await _pump(tester, chart);

      final bars = _data(tester).lineBarsData;
      expect(bars, hasLength(3));

      expect(bars[0].spots, hasLength(2));
      expect(bars[0].spots[0].isNull(), isTrue);
      expect(bars[0].spots[1], const FlSpot(1, 710));
      expect(bars[0].dashArray, isNull);
      expect(bars[0].color, _colors[0]);

      expect(bars[1].spots, const [FlSpot(1, 710), FlSpot(2, 0)]);
      expect(bars[1].dashArray, [5, 4]);
      expect(bars[1].color, _colors[0]);

      expect(bars[2].isStepLineChart, isTrue);
      expect(
        bars[2].lineChartStepData.stepDirection,
        LineChartStepData.stepDirectionMiddle,
      );
      expect(bars[2].dashArray, [6, 4]);
      expect(bars[2].barWidth, 2);
      expect(bars[2].dotData.show, isFalse);
      // Each period's limit holds across its whole slot, half a slot beyond
      // the first and last period's own x.
      expect(bars[2].spots, const [
        FlSpot(-0.5, 800),
        FlSpot(0, 800),
        FlSpot(1, 900),
        FlSpot(2, 700),
        FlSpot(2.5, 700),
      ]);
      expect(bars[2].color, _colors[0].withValues(alpha: 0.55));
    });

    testWidgets('the last dot of the dashed stretch is hollow, in the card '
        'colour with a stroke in the line colour', (tester) async {
      final chart = _chart([
        _line('Groceries', [10, 20, 30]),
      ], inProgress: 2);
      await _pump(tester, chart);

      final dashed = _data(tester).lineBarsData[1];
      final dots = dashed.dotData;
      expect(dots.show, isTrue);
      // The first spot is the solid run's last one, which that bar draws.
      expect(dots.checkToShowDot(dashed.spots.first, dashed), isFalse);
      expect(dots.checkToShowDot(dashed.spots.last, dashed), isTrue);

      final painter =
          dots.getDotPainter(dashed.spots.last, 0, dashed, 1)
              as FlDotCirclePainter;
      final card = AppTheme.darkTheme.colorScheme.surfaceContainerLow;
      expect(painter.color, card);
      expect(painter.strokeColor, _colors[0]);
      expect(painter.strokeWidth, greaterThan(0));

      // The solid run's dots are filled with the line colour.
      final solid = _data(tester).lineBarsData[0];
      final filled =
          solid.dotData.getDotPainter(solid.spots.last, 0, solid, 0)
              as FlDotCirclePainter;
      expect(filled.color, _colors[0]);
    });

    testWidgets('the hollow dot takes the light theme card colour', (
      tester,
    ) async {
      final chart = _chart([
        _line('Groceries', [10, 20]),
      ], inProgress: 1);
      await _pump(tester, chart, theme: AppTheme.lightTheme);

      final dashed = _data(tester).lineBarsData[1];
      final painter =
          dashed.dotData.getDotPainter(dashed.spots.last, 0, dashed, 1)
              as FlDotCirclePainter;
      expect(
        painter.color,
        AppTheme.lightTheme.colorScheme.surfaceContainerLowest,
      );
    });

    testWidgets('without a period in progress each line is one solid run', (
      tester,
    ) async {
      final chart = StatsChart(
        periods: _periods(3),
        lines: [
          StatsLine(
            subject: StatsSubject.tag('coffee'),
            role: StatsLineRole.value,
            values: const [0, 10, 0],
          ),
        ],
      );
      await _pump(tester, chart);

      final bars = _data(tester).lineBarsData;
      expect(bars, hasLength(1));
      expect(bars[0].spots, hasLength(3));
      expect(bars[0].dashArray, isNull);
    });

    testWidgets('a single period holds its limit across its whole slot', (
      tester,
    ) async {
      final chart = _chart([
        _line('Groceries', [42], limits: [400]),
      ]);
      await _pump(tester, chart);

      // One spot would be a zero-length path, which fl_chart dashes into
      // nothing: the bar must run from one edge of the slot to the other.
      final runs = _runs(_limitBar(tester));
      expect(runs, hasLength(1));
      expect(runs.single.first, const FlSpot(-0.5, 400));
      expect(runs.single.last, const FlSpot(0.5, 400));
      expect(runs.single.every((spot) => spot.y == 400), isTrue);
    });

    // fl_chart dashes each stretch on its own, and a stretch of one spot is a
    // zero-length path that dashes into no pixel at all.
    for (final (name, limits) in [
      ('a single period', <double?>[400]),
      (
        'a limited period between two unlimited ones',
        <double?>[null, 400, null],
      ),
      ('a limit on the first and last period only', <double?>[400, null, 400]),
      ('two limited neighbours', <double?>[400, 400]),
    ]) {
      testWidgets('on screen: $name', (tester) async {
        // The line itself has no figure, so only the limit is blue.
        final chart = _chart([
          _line(
            'Groceries',
            List<double?>.filled(limits.length, null),
            limits: limits,
          ),
        ]);
        await _pump(tester, chart);

        expect(await _bluePixels(tester), greaterThan(0));
      });
    }

    testWidgets('a limited period between two unlimited ones is drawn too', (
      tester,
    ) async {
      final chart = _chart([
        _line('Groceries', [5, 6, 7], limits: [null, 400, null]),
      ]);
      await _pump(tester, chart);

      final runs = _runs(_limitBar(tester));
      expect(runs, hasLength(1));
      expect(runs.single.first, const FlSpot(0.5, 400));
      expect(runs.single.last, const FlSpot(1.5, 400));
    });

    testWidgets('a period without a limit leaves a gap between two slots', (
      tester,
    ) async {
      final chart = _chart([
        _line('Groceries', [5, 6, 7], limits: [500, null, 300]),
      ]);
      await _pump(tester, chart);

      final runs = _runs(_limitBar(tester));
      expect(runs, hasLength(2));
      expect(runs[0].first, const FlSpot(-0.5, 500));
      expect(runs[0].last, const FlSpot(0.5, 500));
      expect(runs[1].first, const FlSpot(1.5, 300));
      expect(runs[1].last, const FlSpot(2.5, 300));
    });

    testWidgets('the limits of neighbouring periods step half way between '
        'them', (tester) async {
      final chart = _chart([
        _line('Groceries', [5, 6, 7], limits: [800, 900, 700]),
      ]);
      await _pump(tester, chart);

      final runs = _runs(_limitBar(tester));
      expect(runs, hasLength(1));
      expect(runs.single.first.x, -0.5);
      expect(runs.single.last.x, 2.5);
      expect(_stepXs(runs.single), [0.5, 1.5]);
    });

    testWidgets('equal neighbouring limits make one flat stretch', (
      tester,
    ) async {
      final chart = _chart([
        _line('Groceries', [5, 6], limits: [400, 400]),
      ]);
      await _pump(tester, chart);

      final runs = _runs(_limitBar(tester));
      expect(runs, hasLength(1));
      expect(runs.single.first, const FlSpot(-0.5, 400));
      expect(runs.single.last, const FlSpot(1.5, 400));
      expect(_stepXs(runs.single), isEmpty);
    });

    testWidgets('a limit that is null in every period draws nothing and '
        'builds', (tester) async {
      final chart = _chart([
        _line('Groceries', [5, 6], limits: [null, null]),
      ]);
      await _pump(tester, chart);

      expect(_runs(_limitBar(tester)), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each line is coloured by its own entry of colors', (
      tester,
    ) async {
      final chart = _chart([
        _line('Groceries', [1, 2]),
        _line('Rent', [3, 4]),
      ]);
      await _pump(tester, chart);

      final bars = _data(tester).lineBarsData;
      expect(bars, hasLength(2));
      expect(bars[0].color, _colors[0]);
      expect(bars[1].color, _colors[1]);
    });

    testWidgets('a single period draws without errors', (tester) async {
      final chart = _chart([
        _line('Groceries', [42]),
      ], inProgress: 0);
      await _pump(tester, chart);

      final data = _data(tester);
      expect(data.lineBarsData[0].spots, const [FlSpot(0, 42)]);
      expect(data.minX, -0.5);
      expect(data.maxX, 0.5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bottom labels show every period up to twelve', (tester) async {
      final chart = _chart([_line('Groceries', List<double?>.filled(12, 1))]);
      await _pump(tester, chart);

      for (final p in chart.periods) {
        expect(find.text(DateFormat('MMM yy').format(p.startDate)), findsOne);
      }
    });

    testWidgets('bottom labels skip every other period past twelve', (
      tester,
    ) async {
      final chart = _chart([_line('Groceries', List<double?>.filled(13, 1))]);
      await _pump(tester, chart);

      for (var i = 0; i < chart.periods.length; i++) {
        final label = DateFormat('MMM yy').format(chart.periods[i].startDate);
        expect(find.text(label), i.isEven ? findsOne : findsNothing);
      }
    });

    testWidgets('left labels use the amount format without decimals', (
      tester,
    ) async {
      final chart = _chart([
        _line('Rent', [0, 12000]),
      ]);
      await _pump(tester, chart);

      // A 0..13200 axis ticks at round thousands, grouped like amounts.
      expect(find.text('0'), findsWidgets);
      expect(find.textContaining(RegExp(r'^\d{1,2},000$')), findsWidgets);
    });

    // Amounts show without decimals, so a fractional tick (0.2, 0.5) would
    // read as a repeat of its neighbour: only whole ticks get a label.
    for (final (name, values) in [
      ('all-zero', <double?>[0, 0, 0]),
      ('small', <double?>[1, 3, 2]),
    ]) {
      testWidgets('left labels are all different for an $name chart', (
        tester,
      ) async {
        await _pump(tester, _chart([_line('Rent', values)]));

        final labels = _leftLabels(tester);
        expect(labels, contains('0'));
        expect(labels.toSet(), hasLength(labels.length), reason: '$labels');
      });
    }

    testWidgets('the tooltip describes the first touched spot only', (
      tester,
    ) async {
      final chart = StatsChart(
        periods: _periods(3),
        lines: [
          _line('Groceries', [100, 1234, null], limits: [800, 1500, null]),
          _line('Rent', [700, 700, 700]),
        ],
      );
      await _pump(tester, chart);

      final data = _data(tester);
      final bars = data.lineBarsData;
      // Solid Groceries, its limit, solid Rent.
      expect(bars, hasLength(3));
      // Groceries' limit holds (1, 1500) as its third spot.
      final touched = [
        LineBarSpot(bars[2], 2, bars[2].spots[1]),
        LineBarSpot(bars[0], 0, bars[0].spots[1]),
        LineBarSpot(bars[1], 1, bars[1].spots[2]),
      ];

      final items = data.lineTouchData.touchTooltipData.getTooltipItems(
        touched,
      );
      expect(items, hasLength(3));
      expect(items[1], isNull);
      expect(items[2], isNull);

      final item = items[0]!;
      expect(item.text, chart.periods[1].name);
      expect(item.textStyle.fontWeight, FontWeight.bold);
      final rows = item.children!.map((s) => s.toPlainText()).join();
      expect(rows, '\nGroceries  1,234\nlimit  1,500\nRent  700');
    });

    group('hovering', () {
      // Groceries has no figure in the last period; Rent has all three, so
      // the last period's tooltip differs from the middle one's.
      final chart = StatsChart(
        periods: _periods(3),
        lines: [
          _line('Groceries', [100, 1234, null], limits: [800, 1500, null]),
          _line('Rent', [700, 700, 700]),
        ],
      );
      const middle = '\nGroceries  1,234\nlimit  1,500\nRent  700';

      Future<(LineChartData, List<LineChartBarData>)> pumpChart(
        WidgetTester tester,
      ) async {
        await _pump(tester, chart);
        final data = _data(tester);
        return (data, data.lineBarsData);
      }

      testWidgets('a limit bar\'s half-slot spot does not move the tooltip to '
          'the next period', (tester) async {
        final (data, bars) = await pumpChart(tester);
        // Solid Groceries, its limit, solid Rent. The limit ends at (1.5,
        // 1500), whose x rounds to period 2.
        final halfSlot = bars[1].spots.last;
        expect(halfSlot, const FlSpot(1.5, 1500));

        final items = data.lineTouchData.touchTooltipData.getTooltipItems([
          LineBarSpot(bars[1], 1, halfSlot),
          LineBarSpot(bars[0], 0, bars[0].spots[1]),
          LineBarSpot(bars[2], 2, bars[2].spots[1]),
        ]);

        expect(items, hasLength(3));
        expect(items[1], isNull);
        expect(items[2], isNull);
        expect(items[0]!.text, chart.periods[1].name);
        expect(items[0]!.children!.map((s) => s.toPlainText()).join(), middle);
      });

      testWidgets('the period comes from the whole-number spot wherever it '
          'is in the touch', (tester) async {
        final (data, bars) = await pumpChart(tester);

        final items = data.lineTouchData.touchTooltipData.getTooltipItems([
          LineBarSpot(bars[1], 1, bars[1].spots.first),
          LineBarSpot(bars[2], 2, bars[2].spots[0]),
        ]);

        expect(items[0]!.text, chart.periods[0].name);
        expect(items[1], isNull);
      });

      testWidgets('half-slot spots alone describe no period', (tester) async {
        final (data, bars) = await pumpChart(tester);

        final items = data.lineTouchData.touchTooltipData.getTooltipItems([
          LineBarSpot(bars[1], 1, bars[1].spots.last),
        ]);

        expect(items, [null]);
      });

      testWidgets('only the lines get a touch indicator, not the limit', (
        tester,
      ) async {
        final (data, bars) = await pumpChart(tester);
        final indicators = data.lineTouchData.getTouchedSpotIndicator;

        // The solid Groceries and Rent bars mark the touched spot...
        for (final bar in [bars[0], bars[2]]) {
          final marked = indicators(bar, const [1]);
          expect(marked, hasLength(1));
          expect(marked.single, isNotNull);
          expect(marked.single!.touchedSpotDotData.show, isTrue);
        }
        // ...the limit bar draws none, whichever of its spots is touched,
        // and still answers once per spot as fl_chart requires.
        expect(indicators(bars[1], const [0, 1, 3]), [null, null, null]);
      });
    });

    group('picking a dot', () {
      // Groceries has no figure in the last period; Rent has all three.
      final chart = StatsChart(
        periods: _periods(3),
        lines: [
          _line('Groceries', [100, 1234, null], limits: [800, 1500, null]),
          _line('Rent', [700, 700, 700]),
        ],
      );

      FlTapUpEvent tapUp() =>
          FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.mouse));

      /// What fl_chart reports for a touch at amount [y] that came near
      /// [spots], each given as (bar index, spot index).
      LineTouchResponse touchAt(
        List<LineChartBarData> bars,
        double y,
        List<(int, int)> spots,
      ) => LineTouchResponse(
        touchLocation: Offset.zero,
        touchChartCoordinate: Offset(0, y),
        lineBarSpots: [
          for (final (bar, spot) in spots)
            TouchLineBarSpot(bars[bar], bar, bars[bar].spots[spot], 0),
        ],
      );

      testWidgets('a tap picks the dot of the tapped period nearest the '
          'touch', (tester) async {
        final picked = <(int, int)>[];
        await _pump(tester, chart, onPointTap: (l, p) => picked.add((l, p)));
        final data = _data(tester);
        final bars = data.lineBarsData;
        // Solid Groceries, its limit, solid Rent. Middle period: Groceries
        // 1,234, Rent 700.
        final callback = data.lineTouchData.touchCallback!;

        callback(tapUp(), touchAt(bars, 1000, [(0, 1), (1, 2), (2, 1)]));
        callback(tapUp(), touchAt(bars, 800, [(2, 1), (0, 1)]));
        // The period comes from a whole-number spot, not from the limit's
        // half-slot end.
        callback(tapUp(), touchAt(bars, 650, [(1, 3), (2, 1)]));

        expect(picked, [(0, 1), (1, 1), (1, 1)]);
      });

      testWidgets('a tap skips a line with a gap in the tapped period', (
        tester,
      ) async {
        final picked = <(int, int)>[];
        await _pump(tester, chart, onPointTap: (l, p) => picked.add((l, p)));
        final data = _data(tester);
        final bars = data.lineBarsData;

        data.lineTouchData.touchCallback!(
          tapUp(),
          touchAt(bars, 1300, [(2, 2)]),
        );

        expect(picked, [(1, 2)]);
      });

      testWidgets('a tap away from every period picks nothing', (tester) async {
        final picked = <(int, int)>[];
        await _pump(tester, chart, onPointTap: (l, p) => picked.add((l, p)));
        final data = _data(tester);
        final bars = data.lineBarsData;
        final callback = data.lineTouchData.touchCallback!;

        callback(tapUp(), null);
        callback(
          tapUp(),
          LineTouchResponse(
            touchLocation: Offset.zero,
            touchChartCoordinate: Offset.zero,
          ),
        );
        // A limit's half-slot end lies between two periods.
        callback(tapUp(), touchAt(bars, 1500, [(1, 3)]));

        expect(picked, isEmpty);
      });

      testWidgets('hovering picks nothing', (tester) async {
        final picked = <(int, int)>[];
        await _pump(tester, chart, onPointTap: (l, p) => picked.add((l, p)));
        final data = _data(tester);

        data.lineTouchData.touchCallback!(
          FlPointerHoverEvent(const PointerHoverEvent()),
          touchAt(data.lineBarsData, 1000, [(0, 1)]),
        );

        expect(picked, isEmpty);
      });

      testWidgets('a click on a dot on screen picks it', (tester) async {
        final picked = <(int, int)>[];
        await _pump(tester, chart, onPointTap: (l, p) => picked.add((l, p)));
        final data = _data(tester);
        // The plot is the chart's box less the 56 px left and 28 px bottom
        // axis labels; x runs from -0.5 to 2.5.
        final box = tester.getRect(find.byType(LineChart));
        final plot = Rect.fromLTRB(
          box.left + 56,
          box.top,
          box.right,
          box.bottom - 28,
        );
        Offset dot(int period, double y) => Offset(
          plot.left + (period + 0.5) / 3 * plot.width,
          plot.top + (data.maxY - y) / (data.maxY - data.minY) * plot.height,
        );

        await tester.tapAt(dot(1, 700));
        await tester.pump();
        await tester.tapAt(dot(1, 1234));
        await tester.pump();

        expect(picked, [(1, 1), (0, 1)]);
      });

      testWidgets('the cursor is a hand over a period\'s dots', (tester) async {
        await _pump(tester, chart, onPointTap: (_, _) {});
        final data = _data(tester);
        final bars = data.lineBarsData;
        final resolve = data.lineTouchData.mouseCursorResolver!;
        final hover = FlPointerHoverEvent(const PointerHoverEvent());

        expect(
          resolve(hover, touchAt(bars, 700, [(2, 1)])),
          SystemMouseCursors.click,
        );
        expect(resolve(hover, null), MouseCursor.defer);
        expect(
          resolve(hover, touchAt(bars, 1500, [(1, 3)])),
          MouseCursor.defer,
        );
      });

      testWidgets('without onPointTap the cursor stays and taps do nothing', (
        tester,
      ) async {
        await _pump(tester, chart);
        final data = _data(tester);
        final touch = data.lineTouchData;
        final response = touchAt(data.lineBarsData, 700, [(2, 1)]);

        expect(
          touch.mouseCursorResolver?.call(
                FlPointerHoverEvent(const PointerHoverEvent()),
                response,
              ) ??
              MouseCursor.defer,
          MouseCursor.defer,
        );
        touch.touchCallback?.call(tapUp(), response);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the picked dot is ringed in its line\'s colour', (
        tester,
      ) async {
        // Only Groceries is blue. The chart animates from one data to the
        // next: let it settle before counting.
        await _pump(tester, chart);
        final plain = await _bluePixels(tester);
        await _pump(tester, chart, selected: (line: 0, period: 1));
        await tester.pumpAndSettle();
        final ringed = await _bluePixels(tester);
        await _pump(tester, chart, selected: (line: 1, period: 1));
        await tester.pumpAndSettle();
        final other = await _bluePixels(tester);

        expect(ringed, greaterThan(plain + 20));
        expect(other, plain);
      });

      testWidgets('the hollow dot of the period in progress can be ringed', (
        tester,
      ) async {
        final current = _chart([
          _line('Groceries', [100, 400, 300]),
        ], inProgress: 2);
        await _pump(tester, current);
        final plain = await _bluePixels(tester);
        await _pump(tester, current, selected: (line: 0, period: 2));
        await tester.pumpAndSettle();

        expect(await _bluePixels(tester), greaterThan(plain + 20));
      });
    });

    testWidgets('builds under the light theme without errors', (tester) async {
      final chart = _chart([
        _line('Groceries', [5, 6, 7], limits: [9, 9, 9]),
      ], inProgress: 2);
      await _pump(tester, chart, theme: AppTheme.lightTheme);

      expect(tester.takeException(), isNull);
    });
  });

  test('statsLineColors: All uses teal and gold, others the palette in order, '
      'wrapping', () {
    final scheme = AppTheme.darkTheme.colorScheme;

    final all = StatsChart(
      periods: const [],
      lines: [
        StatsLine(
          subject: StatsSubject.all,
          role: StatsLineRole.spent,
          values: const [],
        ),
        StatsLine(
          subject: StatsSubject.all,
          role: StatsLineRole.earned,
          values: const [],
        ),
      ],
    );
    expect(statsLineColors(all, scheme), [scheme.secondary, scheme.primary]);

    final tags = StatsChart(
      periods: const [],
      lines: [
        for (var i = 0; i < 10; i++)
          StatsLine(
            subject: StatsSubject.tag('t$i'),
            role: StatsLineRole.value,
            values: const [],
          ),
      ],
    );
    final colors = statsLineColors(tags, scheme);
    expect(colors.sublist(0, 8), statsPalette);
    expect(colors[8], statsPalette[0]);
    expect(colors[9], statsPalette[1]);
  });

  test(
    'statsPalette has eight colours and leaves out teal, gold and coral',
    () {
      final scheme = AppTheme.darkTheme.colorScheme;
      expect(statsPalette, hasLength(8));
      expect(statsPalette.toSet(), hasLength(8));
      expect(statsPalette, isNot(contains(scheme.error)));
      expect(statsPalette, isNot(contains(scheme.secondary)));
      expect(statsPalette, isNot(contains(scheme.primary)));
    },
  );

  test('bottom labels thin out past twelve periods', () {
    expect(bottomLabelInterval(1), 1);
    expect(bottomLabelInterval(12), 1);
    expect(bottomLabelInterval(13), 2);
    expect(bottomLabelInterval(36), 3);
  });

  group('statsYBounds', () {
    test('reach below zero for a negative total', () {
      final chart = _chart([
        _line('Refunds', [-40, 100], limits: [null, 120]),
      ]);
      expect(statsYBounds(chart), (minY: -44.0, maxY: 132.0));
    });

    test('start at zero and add a tenth of headroom for positive figures', () {
      final chart = _chart([
        _line('Rent', [200, 500]),
      ]);
      final bounds = statsYBounds(chart);
      expect(bounds.minY, 0);
      expect(bounds.maxY, closeTo(550, 1e-9));
    });

    test('are 0 to 1 when everything is zero or a gap', () {
      final chart = _chart([
        _line('Rent', [0, null, 0]),
      ]);
      expect(statsYBounds(chart), (minY: 0.0, maxY: 1.0));
    });
  });
}
