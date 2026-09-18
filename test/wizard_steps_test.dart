import 'package:flatplan/src/components/wizard_steps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const labels = ['Connect', 'Repository', 'Location'];

  Widget app(int current) => MaterialApp(
    home: Scaffold(body: WizardSteps(labels: labels, current: current)),
  );

  testWidgets('shows every label and numbers the steps', (tester) async {
    await tester.pumpWidget(app(0));

    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('completed steps show a check instead of their number', (tester) async {
    await tester.pumpWidget(app(2));

    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('announces the current step for assistive tech', (tester) async {
    await tester.pumpWidget(app(1));

    expect(find.bySemanticsLabel('Step 2 of 3: Repository'), findsOneWidget);
  });
}
