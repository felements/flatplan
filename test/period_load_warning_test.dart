import 'package:flatplan/src/components/period_load_warning.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PeriodLoadFailure _failure(String fileName, String message) =>
    PeriodLoadFailure(
      fileName: fileName,
      path: '/periods/$fileName',
      message: message,
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('banner renders nothing when no files failed', (tester) async {
    await tester.pumpWidget(
      _wrap(PeriodLoadBanner(failures: const [], onViewDetails: () {})),
    );

    expect(find.byType(Card), findsNothing);
    expect(find.textContaining('could not be read'), findsNothing);
  });

  testWidgets('banner summarises a single unreadable file', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PeriodLoadBanner(
          failures: [_failure('broken.yaml', 'line 1, column 1: bad')],
          onViewDetails: () {},
        ),
      ),
    );

    expect(find.text('1 period file could not be read'), findsOneWidget);
  });

  testWidgets('banner pluralises and reports details on tap', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _wrap(
        PeriodLoadBanner(
          failures: [
            _failure('a.yaml', 'boom'),
            _failure('b.yaml', 'boom'),
          ],
          onViewDetails: () => tapped++,
        ),
      ),
    );

    expect(find.text('2 period files could not be read'), findsOneWidget);

    await tester.tap(find.text('View details'));
    await tester.pump();

    expect(tapped, 1);
  });

  testWidgets('failure list shows each filename with its error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        PeriodLoadFailureList(
          failures: [
            _failure('2026-03-march.yaml', 'line 4, column 2: bad indentation'),
            _failure('list.yaml', 'top level is not a mapping'),
          ],
        ),
      ),
    );

    expect(find.text('2026-03-march.yaml'), findsOneWidget);
    expect(find.text('line 4, column 2: bad indentation'), findsOneWidget);
    expect(find.text('list.yaml'), findsOneWidget);
    expect(find.text('top level is not a mapping'), findsOneWidget);
  });

  testWidgets('failure list renders nothing when there are no failures', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const PeriodLoadFailureList(failures: [])));

    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });
}
