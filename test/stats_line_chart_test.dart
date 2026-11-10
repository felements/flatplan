import 'package:fl_chart/fl_chart.dart';
import 'package:flatplan/src/app_theme.dart';
import 'package:flatplan/src/components/stats_line_chart.dart';
import 'package:flatplan/src/logic/stats_series.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flutter/material.dart';
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
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme ?? AppTheme.darkTheme,
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: 300,
        child: StatsLineChart(chart: chart, colors: _colors),
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
      expect(bars[2].spots, const [
        FlSpot(0, 800),
        FlSpot(1, 900),
        FlSpot(2, 700),
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

    testWidgets('a null limit becomes a gap in the limit bar', (tester) async {
      final chart = _chart([
        _line('Groceries', [5, 6], limits: [null, 9]),
      ]);
      await _pump(tester, chart);

      final bars = _data(tester).lineBarsData;
      expect(bars, hasLength(2));
      expect(bars[1].spots[0].isNull(), isTrue);
      expect(bars[1].spots[1], const FlSpot(1, 9));
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
      final touched = [
        LineBarSpot(bars[2], 2, bars[2].spots[1]),
        LineBarSpot(bars[0], 0, bars[0].spots[1]),
        LineBarSpot(bars[1], 1, bars[1].spots[1]),
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
