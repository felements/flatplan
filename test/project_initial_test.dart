import 'package:flatplan/src/views/project_initial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the upper-cased initial on the theme primary container', (tester) async {
    final theme = ThemeData(colorSchemeSeed: Colors.teal);
    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const Scaffold(body: ProjectInitial(name: 'notes'))),
    );

    expect(find.text('N'), findsOneWidget);
    final box = tester.widget<Container>(find.byType(Container));
    expect((box.decoration as BoxDecoration).color, theme.colorScheme.primaryContainer);
  });
}
