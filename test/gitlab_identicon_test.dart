import 'package:flatplan/src/views/gitlab_identicon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the background follows GitLab: project id modulo the palette size', () {
    expect(GitLabIdenticon.colorFor(0), GitLabIdenticon.palette[0]);
    expect(GitLabIdenticon.colorFor(42), GitLabIdenticon.palette[42 % GitLabIdenticon.palette.length]);
    expect(GitLabIdenticon.palette.length, 7);
  });

  testWidgets('shows the upper-cased initial on the id colour', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GitLabIdenticon(id: 42, name: 'notes'))),
    );

    expect(find.text('N'), findsOneWidget);
    final box = tester.widget<Container>(find.byType(Container));
    expect((box.decoration as BoxDecoration).color, GitLabIdenticon.colorFor(42));
  });
}
