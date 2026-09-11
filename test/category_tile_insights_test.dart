import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/components/category_tile.dart';

Widget _tile({
  String? dailyAllowanceAmount = '400',
  String? safeBasketAmount,
  String? trendLine,
  bool isOverProjected = false,
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
      trendLine: trendLine,
      isOverProjected: isOverProjected,
      onTap: () {},
    ),
  ),
);

void main() {
  testWidgets('leads with the safe-per-shop amount when available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _tile(safeBasketAmount: '550', trendLine: 'averaging 520/day — heading 2,400 over'),
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
}
