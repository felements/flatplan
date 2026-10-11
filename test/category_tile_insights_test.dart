import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/components/category_tile.dart';

Widget _tile({
  String? dailyAllowanceAmount = '400',
  String? safeBasketAmount,
  String? typicalLine,
  String? trendLine,
  bool isOverProjected = false,
  String? pastPaceLine,
  bool isOverPace = false,
}) => MaterialApp(
  home: Scaffold(
    body: CategoryTile(
      title: 'Groceries',
      spentAmount: '2,000',
      limitAmount: '10,000',
      heatPercentage: 0.2,
      isOverBudget: false,
      dailyAllowanceAmount: dailyAllowanceAmount,
      safeBasketAmount: safeBasketAmount,
      typicalLine: typicalLine,
      trendLine: trendLine,
      isOverProjected: isOverProjected,
      pastPaceLine: pastPaceLine,
      isOverPace: isOverPace,
      onTap: () {},
    ),
  ),
);

void main() {
  testWidgets('leads with the safe-per-shop amount when available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _tile(
        safeBasketAmount: '550',
        trendLine: 'averaging 520/day — heading 2,400 over',
      ),
    );

    expect(find.textContaining('550 safe per shop'), findsOneWidget);
    expect(find.textContaining('400 / day left'), findsOneWidget);
    expect(
      find.textContaining('averaging 520/day — heading 2,400 over'),
      findsOneWidget,
    );
  });

  testWidgets('falls back to the daily figure alone', (tester) async {
    await tester.pumpWidget(_tile());

    expect(find.textContaining('400 / day left'), findsOneWidget);
    expect(find.textContaining('safe per shop'), findsNothing);
  });
  testWidgets('shows the typical-purchase line when there is no basket', (
    tester,
  ) async {
    await tester.pumpWidget(
      _tile(typicalLine: 'usually 60, about one every 4 days'),
    );

    expect(find.textContaining('400 / day left'), findsOneWidget);
    expect(
      find.textContaining('usually 60, about one every 4 days'),
      findsOneWidget,
    );
  });

  testWidgets('prefers the basket figure over the typical one', (tester) async {
    await tester.pumpWidget(
      _tile(
        safeBasketAmount: '550',
        typicalLine: 'usually 60, about one every 4 days',
      ),
    );

    expect(find.textContaining('550 safe per shop'), findsOneWidget);
    expect(find.textContaining('usually 60'), findsNothing);
  });

  testWidgets('a finished period shows its pace instead of a daily figure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _tile(
        dailyAllowanceAmount: null,
        pastPaceLine: 'averaged 35/day of 40/day planned',
      ),
    );

    expect(
      find.textContaining('averaged 35/day of 40/day planned'),
      findsOneWidget,
    );
    expect(find.textContaining('/ day left'), findsNothing);
  });

  testWidgets('a pace above plan is drawn in the error colour', (tester) async {
    Color? paceColor(WidgetTester tester) =>
        tester.widget<Text>(find.textContaining('averaged')).style?.color;

    await tester.pumpWidget(
      _tile(
        dailyAllowanceAmount: null,
        pastPaceLine: 'averaged 47/day of 40/day planned',
        isOverPace: true,
      ),
    );
    final error = Theme.of(
      tester.element(find.byType(CategoryTile)),
    ).colorScheme.error;
    expect(paceColor(tester), error);

    await tester.pumpWidget(
      _tile(
        dailyAllowanceAmount: null,
        pastPaceLine: 'averaged 35/day of 40/day planned',
      ),
    );
    expect(paceColor(tester), isNot(error));
  });
}
