import 'package:flatplan/src/app_theme.dart';
import 'package:flatplan/src/components/stats_line_chart.dart';
import 'package:flatplan/src/logic/stats_series.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/stats_fixtures.dart';

/// The left axis labels on screen: whole-number texts, which the period
/// labels ('Jan 26') are not.
List<String> _leftLabels(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    if (RegExp(r'^-?[\d,]+$').hasMatch(text.data ?? '')) text.data!,
];

void main() {
  // The app's own font, whose digits differ in width: the test font draws
  // every glyph as the same square and would hide a label squeezed by a
  // narrower one.
  setUpAll(() async {
    final outfit = FontLoader('Outfit')
      ..addFont(rootBundle.load('assets/fonts/Outfit-VariableFont_wght.ttf'));
    await outfit.load();
  });

  for (final (name, values) in [
    ('six-figure', <double?>[180000, 250000, 120000]),
    ('negative six-figure', <double?>[-150000, 40000, 250000]),
    // The axis tops out at 1,111,111: narrow ones, below labels of wide
    // zeros such as 1,000,000.
    ('narrow-digit', <double?>[1010101, 400000, 900000]),
  ]) {
    testWidgets('left labels stay on one line for $name amounts', (
      tester,
    ) async {
      final chart = StatsChart(
        periods: [
          for (var i = 0; i < values.length; i++)
            period('p$i', DateTime(2026, 1 + i, 5), []),
        ],
        lines: [
          StatsLine(
            subject: StatsSubject.category('Spent', income: false),
            role: StatsLineRole.value,
            values: values,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 300,
              child: StatsLineChart(
                chart: chart,
                colors: const [Color(0xFF388CF0)],
              ),
            ),
          ),
        ),
      );

      final labels = _leftLabels(tester);
      expect(labels.where((l) => l.length >= 7), isNotEmpty);
      // A label squeezed onto two lines stands taller than '0'.
      final oneLine = tester.getSize(find.text('0')).height;
      for (final label in labels) {
        expect(tester.getSize(find.text(label)).height, oneLine, reason: label);
      }
    });
  }
}
