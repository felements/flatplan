import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/components/category_tile.dart';

Widget _tile({required bool plannedExceedsLimit}) => MaterialApp(
  home: Scaffold(
    body: CategoryTile(
      title: 'Rent',
      spentAmount: '€500',
      limitAmount: '€1,200',
      heatPercentage: 0.42,
      isOverBudget: false,
      plannedExceedsLimit: plannedExceedsLimit,
      onTap: () {},
    ),
  ),
);

void main() {
  testWidgets('shows amber warning icon when planned exceeds limit', (
    tester,
  ) async {
    await tester.pumpWidget(_tile(plannedExceedsLimit: true));

    final iconFinder = find.byIcon(Icons.warning_amber_rounded);
    expect(iconFinder, findsOneWidget);

    final tooltip = find.ancestor(
      of: iconFinder,
      matching: find.byType(Tooltip),
    );
    expect(tooltip, findsOneWidget);
    expect(
      tester.widget<Tooltip>(tooltip).message,
      'Planned expenses exceed the limit',
    );
  });

  testWidgets('no warning icon when flag is false', (tester) async {
    await tester.pumpWidget(_tile(plannedExceedsLimit: false));
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });
}
