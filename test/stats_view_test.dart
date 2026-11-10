import 'dart:async';

import 'package:flatplan/src/app_theme.dart';
import 'package:flatplan/src/components/period_load_warning.dart';
import 'package:flatplan/src/components/stats_line_chart.dart';
import 'package:flatplan/src/components/tag_chip.dart';
import 'package:flatplan/src/logic/stats_series.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/all_periods_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/views/stats_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'support/stats_fixtures.dart';

DateTime _midnightDaysAgo(int days) {
  final d = DateTime.now().subtract(Duration(days: days));
  return DateTime(d.year, d.month, d.day);
}

String _month(DateTime date) => DateFormat('MMM yyyy').format(date);

/// Three periods, the newest covering today: Groceries and Home to spend on,
/// Salary to earn, and a `#renovation` payment.
List<Period> _fixture() => [
  for (final (id, daysAgo) in [('old', 70), ('mid', 40), ('new', 5)])
    period(id, _midnightDaysAgo(daysAgo), [
      category('Groceries', limit: 400, facts: [(50, null)]),
      category('Home', facts: [(120, '#renovation')]),
      category('Salary', type: CategoryType.income, facts: [(2000, null)]),
    ]),
];

/// A workspace that holds back listing its files while [gate] is set, to keep
/// a reload of the periods under way.
class _GatedWorkspace extends MemoryWorkspace {
  Completer<void>? gate;

  @override
  Future<List<String>> listFiles() async {
    await gate?.future;
    return super.listFiles();
  }
}

Future<PeriodRepository> _repoWith(
  List<Period> periods, {
  Map<String, String> files = const {},
  VaultWorkspace? workspace,
}) async {
  final repo = PeriodRepository(workspace: workspace ?? MemoryWorkspace());
  for (final period in periods) {
    await repo.savePeriod(period);
  }
  for (final MapEntry(:key, :value) in files.entries) {
    await repo.workspace.writeString(key, value);
  }
  return repo;
}

/// Pumps the page over a vault holding [periods] and returns its repository.
///
/// [files] are extra files in the vault, e.g. one that is not a period. The
/// page sits at `/` of a router that also knows `/settings`, as the app's does.
Future<PeriodRepository> _pump(
  WidgetTester tester,
  List<Period> periods, {
  Size size = const Size(1400, 900),
  ThemeData? theme,
  Map<String, String> files = const {},
  VaultWorkspace? workspace,
}) async {
  final repo = await _repoWith(periods, files: files, workspace: workspace);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: StatsView()),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const Text('settings page'),
      ),
    ],
  );
  addTearDown(router.dispose);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.runAsync(() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
        child: MaterialApp.router(theme: theme, routerConfig: router),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
  });
  return repo;
}

StatsChart _chart(WidgetTester tester) =>
    tester.widget<StatsLineChart>(find.byType(StatsLineChart)).chart;

List<String> _labels(WidgetTester tester) => [
  for (final line in _chart(tester).lines) line.label,
];

Finder _row(String key) => find.byKey(ValueKey('stats-subject-$key'));

bool _ticked(WidgetTester tester, String key) => tester
    .widget<Checkbox>(
      find.descendant(of: _row(key), matching: find.byType(Checkbox)),
    )
    .value!;

/// The colours of the round dots inside [scope].
List<Color> _dots(WidgetTester tester, Finder scope) => [
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(of: scope, matching: find.byType(DecoratedBox)),
  ))
    if (box.decoration case BoxDecoration(
      shape: BoxShape.circle,
      color: final color?,
    ))
      color,
];

Future<void> _tapRow(WidgetTester tester, String key) async {
  await tester.tap(_row(key));
  await tester.pumpAndSettle();
}

/// Opens the range dialog and picks [value] in the dropdown keyed [key].
Future<void> _pickMonth(WidgetTester tester, String key, DateTime value) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_month(value)).last);
  await tester.pumpAndSettle();
}

Future<void> _openRangeDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('stats-range')));
  await tester.pumpAndSettle();
}

Future<void> _chooseFromTo(WidgetTester tester) async {
  await tester.tap(find.text('From – to'));
  await tester.pumpAndSettle();
}

Future<void> _apply(WidgetTester tester) async {
  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();
}

/// Narrows the page to the month of the period 5 days ago, then deletes that
/// period and reloads the periods as the app does after a change, so the range
/// is left matching nothing.
Future<void> _leaveRangeStale(
  WidgetTester tester,
  PeriodRepository repo,
  DateTime newest,
) async {
  await _openRangeDialog(tester);
  await _chooseFromTo(tester);
  await _pickMonth(tester, 'stats-range-from', newest);
  await _apply(tester);
  expect(_chart(tester).periods, hasLength(1));

  final container = ProviderScope.containerOf(
    tester.element(find.byType(StatsView)),
  );
  // As _pump does for the first load: the files are read in real time.
  await tester.runAsync(() async {
    await repo.workspace.delete(repo.filenameForPeriod('new')!);
    container.invalidate(periodLoadResultProvider);
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
  });
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The test font draws every glyph as a full square, far wider than the
  // app's own Outfit: load it, so a test with the app theme measures text as
  // the user sees it.
  setUpAll(() async {
    final outfit = FontLoader('Outfit')
      ..addFont(rootBundle.load('assets/fonts/Outfit-VariableFont_wght.ttf'));
    await outfit.load();
  });

  final newest = DateTime(_midnightDaysAgo(5).year, _midnightDaysAgo(5).month);
  final oldest = DateTime(
    _midnightDaysAgo(70).year,
    _midnightDaysAgo(70).month,
  );

  group('StatsView', () {
    testWidgets('opens on All with spent and earned lines', (tester) async {
      await _pump(tester, _fixture());

      expect(_ticked(tester, 'all-'), isTrue);
      expect(_labels(tester), ['Spent', 'Earned']);
      // The legend names both lines beside the chart.
      expect(find.text('Spent'), findsOneWidget);
      expect(find.text('Earned'), findsOneWidget);
      expect(find.text('All periods'), findsOneWidget);
      expect(find.byKey(const ValueKey('stats-list-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('stats-graph-card')), findsOneWidget);
    });

    testWidgets('groups the subjects under TOTALS, EXPENSES, INCOME and TAGS', (
      tester,
    ) async {
      await _pump(tester, _fixture());

      for (final heading in ['TOTALS', 'EXPENSES', 'INCOME', 'TAGS']) {
        expect(find.text(heading), findsOneWidget);
      }
      expect(find.text('All (spent & earned)'), findsOneWidget);
      expect(_row('expenseCategory-groceries'), findsOneWidget);
      expect(_row('expenseCategory-home'), findsOneWidget);
      expect(_row('incomeCategory-salary'), findsOneWidget);
      expect(_row('tag-renovation'), findsOneWidget);
    });

    testWidgets('ticking a category replaces All; unticking it brings All '
        'back', (tester) async {
      await _pump(tester, _fixture());

      await _tapRow(tester, 'expenseCategory-groceries');
      expect(_labels(tester), ['Groceries']);
      expect(_ticked(tester, 'all-'), isFalse);
      expect(_ticked(tester, 'expenseCategory-groceries'), isTrue);

      await _tapRow(tester, 'expenseCategory-groceries');
      expect(_labels(tester), ['Spent', 'Earned']);
      expect(_ticked(tester, 'all-'), isTrue);
      expect(_ticked(tester, 'expenseCategory-groceries'), isFalse);
    });

    testWidgets('several subjects make several lines in tick order', (
      tester,
    ) async {
      await _pump(tester, _fixture());

      await _tapRow(tester, 'expenseCategory-groceries');
      await _tapRow(tester, 'tag-renovation');

      expect(_labels(tester), ['Groceries', 'renovation']);
      // The legend repeats each name beside the list's own row.
      expect(find.text('Groceries'), findsNWidgets(2));
      expect(find.text('renovation'), findsNWidgets(2));
    });

    testWidgets('a ticked row shows its line colour and an unticked one none', (
      tester,
    ) async {
      await _pump(tester, _fixture(), theme: AppTheme.darkTheme);
      final scheme = AppTheme.darkTheme.colorScheme;

      // All is two lines, spent in teal and earned in gold.
      expect(_dots(tester, _row('all-')), [scheme.secondary, scheme.primary]);
      expect(_dots(tester, _row('expenseCategory-groceries')), isEmpty);

      await _tapRow(tester, 'expenseCategory-groceries');
      await _tapRow(tester, 'tag-renovation');

      expect(_dots(tester, _row('all-')), isEmpty);
      expect(_dots(tester, _row('expenseCategory-groceries')), [
        statsPalette[0],
      ]);
      expect(_dots(tester, _row('tag-renovation')), [statsPalette[1]]);
    });

    testWidgets('search filters the list', (tester) async {
      await _pump(tester, _fixture());
      expect(find.text('Home'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'gro');
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsNothing);
      expect(find.text('Groceries'), findsOneWidget);
    });

    testWidgets('search ignores case and hides groups with no match', (
      tester,
    ) async {
      await _pump(tester, _fixture());

      await tester.enterText(find.byType(TextField), 'RENO');
      await tester.pumpAndSettle();

      expect(find.text('TAGS'), findsOneWidget);
      expect(_row('tag-renovation'), findsOneWidget);
      for (final heading in ['TOTALS', 'EXPENSES', 'INCOME']) {
        expect(find.text(heading), findsNothing);
      }
    });

    testWidgets('a from–to range narrows the periods', (tester) async {
      await _pump(tester, _fixture());
      expect(_chart(tester).periods, hasLength(3));

      await _openRangeDialog(tester);
      await _chooseFromTo(tester);
      await _pickMonth(tester, 'stats-range-from', newest);
      await _apply(tester);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('stats-range')),
          matching: find.text('${_month(newest)} – ${_month(newest)}'),
        ),
        findsOneWidget,
      );
      expect(_chart(tester).periods, hasLength(1));
    });

    testWidgets('a from-month later than the to-month moves the to-month', (
      tester,
    ) async {
      await _pump(tester, _fixture());

      await _openRangeDialog(tester);
      await _chooseFromTo(tester);
      await _pickMonth(tester, 'stats-range-to', oldest);
      await _pickMonth(tester, 'stats-range-from', newest);
      await _apply(tester);

      expect(
        find.text('${_month(newest)} – ${_month(newest)}'),
        findsOneWidget,
      );
    });

    testWidgets('a to-month earlier than the from-month moves the from-month', (
      tester,
    ) async {
      await _pump(tester, _fixture());

      await _openRangeDialog(tester);
      await _chooseFromTo(tester);
      await _pickMonth(tester, 'stats-range-from', newest);
      await _pickMonth(tester, 'stats-range-to', oldest);
      await _apply(tester);

      expect(
        find.text('${_month(oldest)} – ${_month(oldest)}'),
        findsOneWidget,
      );
    });

    testWidgets('choosing All periods again clears the range', (tester) async {
      await _pump(tester, _fixture());
      await _openRangeDialog(tester);
      await _chooseFromTo(tester);
      await _pickMonth(tester, 'stats-range-from', newest);
      await _apply(tester);
      expect(_chart(tester).periods, hasLength(1));

      await _openRangeDialog(tester);
      // The dialog reopens on the range it applied.
      expect(
        tester
            .widget<DropdownButton<DateTime>>(
              find.byKey(const ValueKey('stats-range-from')),
            )
            .value,
        newest,
      );
      // 'All periods' is both the radio and, once cleared, the button label.
      await tester.tap(find.widgetWithText(RadioListTile<bool>, 'All periods'));
      await tester.pumpAndSettle();
      await _apply(tester);

      expect(find.text('All periods'), findsOneWidget);
      expect(_chart(tester).periods, hasLength(3));
    });

    testWidgets('a range does not shorten the list of subjects', (
      tester,
    ) async {
      // Only the oldest period has a Bakery category.
      final periods = _fixture();
      periods[0] = period('old', _midnightDaysAgo(70), [
        category('Bakery', facts: [(5, null)]),
        category('Groceries', facts: [(50, null)]),
      ]);
      await _pump(tester, periods);

      await _openRangeDialog(tester);
      await _chooseFromTo(tester);
      await _pickMonth(tester, 'stats-range-from', newest);
      await _apply(tester);

      expect(_chart(tester).periods, hasLength(1));
      expect(_row('expenseCategory-bakery'), findsOneWidget);
    });

    testWidgets('a range left matching no period says so and draws no chart', (
      tester,
    ) async {
      final repo = await _pump(tester, _fixture());
      await _leaveRangeStale(tester, repo, newest);

      expect(find.text('No periods in this range.'), findsOneWidget);
      expect(find.byType(StatsLineChart), findsNothing);
      expect(tester.takeException(), isNull);
      // The button still names the range, and the legend its lines.
      expect(
        find.text('${_month(newest)} – ${_month(newest)}'),
        findsOneWidget,
      );
      expect(find.text('Spent'), findsOneWidget);
    });

    testWidgets('reopening the dialog on a stale range falls back to the '
        'months that remain', (tester) async {
      final repo = await _pump(tester, _fixture());
      await _leaveRangeStale(tester, repo, newest);

      await _openRangeDialog(tester);

      expect(tester.takeException(), isNull);
      final remaining = [
        for (final days in [70, 40])
          DateTime(_midnightDaysAgo(days).year, _midnightDaysAgo(days).month),
      ];
      DateTime? value(String key) => tester
          .widget<DropdownButton<DateTime>>(find.byKey(ValueKey(key)))
          .value;
      expect(value('stats-range-from'), remaining.first);
      expect(value('stats-range-to'), remaining.last);

      // Applying the fallback span brings the chart back.
      await _apply(tester);
      expect(_chart(tester).periods, hasLength(2));
      expect(find.text('No periods in this range.'), findsNothing);
    });

    testWidgets('an empty vault says there is nothing to chart', (
      tester,
    ) async {
      await _pump(tester, const []);

      expect(find.text('No periods to chart yet.'), findsOneWidget);
      expect(find.byType(StatsLineChart), findsNothing);
      expect(find.byKey(const ValueKey('stats-list-card')), findsNothing);
    });

    testWidgets('a vault of only future periods says there is nothing to '
        'chart yet', (tester) async {
      await _pump(tester, [
        period('next', _midnightDaysAgo(-10), [category('Groceries')]),
      ]);

      expect(find.text('No periods to chart yet.'), findsOneWidget);
      expect(find.byType(StatsLineChart), findsNothing);
    });

    testWidgets('says so when the subjects have nothing recorded', (
      tester,
    ) async {
      await _pump(tester, [
        period('only', _midnightDaysAgo(5), [category('Groceries')]),
      ]);

      expect(find.byType(StatsLineChart), findsOneWidget);
      expect(
        find.text('Nothing recorded for these subjects in this range.'),
        findsOneWidget,
      );
    });

    testWidgets('does not warn about an empty chart when there is data', (
      tester,
    ) async {
      await _pump(tester, _fixture());

      expect(
        find.text('Nothing recorded for these subjects in this range.'),
        findsNothing,
      );
    });

    testWidgets('keeps the search text when the window changes size', (
      tester,
    ) async {
      await _pump(tester, _fixture());
      await tester.enterText(find.byType(TextField), 'gro');
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(680, 800);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'gro'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('lays out in a narrow window without overflow', (tester) async {
      await _pump(tester, _fixture(), size: const Size(680, 800));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('stats-list-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('stats-graph-card')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('stats-list-card'))).height,
        lessThanOrEqualTo(240),
      );
    });

    testWidgets('puts the cards side by side in a wide window', (tester) async {
      await _pump(tester, _fixture());

      final list = tester.getRect(
        find.byKey(const ValueKey('stats-list-card')),
      );
      final graph = tester.getRect(
        find.byKey(const ValueKey('stats-graph-card')),
      );
      expect(list.width, 220);
      expect(graph.left - list.right, 16);
    });

    testWidgets('the ticked All row shows its whole label beside its two '
        'dots', (tester) async {
      // The real theme: its font is wider than the test one.
      await _pump(tester, _fixture(), theme: AppTheme.darkTheme);
      expect(_ticked(tester, 'all-'), isTrue);
      expect(_dots(tester, _row('all-')), hasLength(2));

      final label = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: _row('all-'),
          matching: find.text('All (spent & earned)'),
        ),
      );
      // Cut short, the label ends in an ellipsis: the paragraph gives up
      // lines it has no room for, or wraps onto a second one.
      expect(label.didExceedMaxLines, isFalse);
      // One box per line of text.
      expect(
        label.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 20),
        ),
        hasLength(1),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('stats-list-card'))).width,
        220,
      );
    });

    testWidgets('warns above the cards when a period file could not be read', (
      tester,
    ) async {
      await _pump(tester, _fixture(), files: {'broken.yaml': 'foo: [1, 2'});

      expect(find.text('1 period file could not be read'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(PeriodLoadBanner)).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byKey(const ValueKey('stats-list-card'))).dy,
        ),
      );
      // The periods that did load are still charted.
      expect(_chart(tester).periods, hasLength(3));
    });

    testWidgets('warns even when no period could be read', (tester) async {
      await _pump(tester, const [], files: {'broken.yaml': 'foo: [1, 2'});

      expect(find.text('1 period file could not be read'), findsOneWidget);
      expect(find.text('No periods to chart yet.'), findsOneWidget);
    });

    testWidgets('does not warn when every file can be read', (tester) async {
      await _pump(tester, _fixture());

      expect(find.textContaining('could not be read'), findsNothing);
      expect(find.text('View details'), findsNothing);
    });

    testWidgets('View details on the warning opens Settings', (tester) async {
      await _pump(tester, _fixture(), files: {'broken.yaml': 'foo: [1, 2'});

      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();

      expect(find.text('settings page'), findsOneWidget);
    });

    testWidgets('a reload keeps the page, and the search focus, on screen', (
      tester,
    ) async {
      final workspace = _GatedWorkspace();
      final repo = await _pump(tester, _fixture(), workspace: workspace);
      await tester.enterText(find.byType(TextField), 'gro');
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(StatsView)),
      );

      await tester.runAsync(() async {
        // As when a sync pull changes a file: the periods are read again,
        // and the read is still going.
        await repo.workspace.delete(repo.filenameForPeriod('old')!);
        workspace.gate = Completer<void>();
        container.invalidate(periodLoadResultProvider);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byKey(const ValueKey('stats-list-card')), findsOneWidget);
        // Still the periods read before.
        expect(_chart(tester).periods, hasLength(3));

        workspace.gate!.complete();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      });

      expect(_chart(tester).periods, hasLength(2));
      expect(find.widgetWithText(TextField, 'gro'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
    });

    group('picking a dot', () {
      final paymentsCard = find.byKey(const ValueKey('stats-payments-card'));

      /// Clicks the dot of the chart's line [line] in the period at [period],
      /// as the chart reports a click.
      Future<void> pick(WidgetTester tester, int line, int period) async {
        tester.widget<StatsLineChart>(find.byType(StatsLineChart)).onPointTap!(
          line,
          period,
        );
        await tester.pumpAndSettle();
      }

      /// The texts inside the payments card.
      List<String> cardTexts(WidgetTester tester) => [
        for (final text in tester.widgetList<Text>(
          find.descendant(of: paymentsCard, matching: find.byType(Text)),
        ))
          text.data ?? text.textSpan!.toPlainText(),
      ];

      testWidgets('no list shows before a dot is picked', (tester) async {
        await _pump(tester, _fixture());

        expect(paymentsCard, findsNothing);
        expect(
          tester.widget<StatsLineChart>(find.byType(StatsLineChart)).selected,
          isNull,
        );
      });

      testWidgets('All\'s spent dot lists the period\'s expense payments under '
          'the graph', (tester) async {
        await _pump(tester, _fixture());
        final name = _chart(tester).periods.last.name;

        await pick(tester, 0, 2);

        expect(paymentsCard, findsOneWidget);
        final texts = cardTexts(tester);
        expect(texts, contains('Spent · $name'));
        expect(texts, contains('2 payments · €170.00'));
        // Each row: the day, the comment, the category and the amount.
        expect(
          texts,
          containsAllInOrder(['No comment', 'Groceries', '€50.00']),
        );
        expect(texts, containsAllInOrder(['Home', '€120.00']));
        expect(texts, contains('2 Jan'));
        expect(texts, isNot(contains('€2,000.00')));
        // The tag is a chip, not text.
        expect(
          find.descendant(of: paymentsCard, matching: find.byType(TagChip)),
          findsOneWidget,
        );
        // The list sits under the graph.
        expect(
          tester.getRect(paymentsCard).top,
          greaterThan(
            tester
                .getRect(find.byKey(const ValueKey('stats-graph-card')))
                .bottom,
          ),
        );
      });

      testWidgets('the picked dot is ringed on the chart', (tester) async {
        await _pump(tester, _fixture());

        await pick(tester, 1, 0);

        expect(
          tester.widget<StatsLineChart>(find.byType(StatsLineChart)).selected,
          (line: 1, period: 0),
        );
        expect(cardTexts(tester), contains('1 payment · €2,000.00'));
      });

      testWidgets('a category\'s list leaves out the category name', (
        tester,
      ) async {
        await _pump(tester, _fixture());
        await _tapRow(tester, 'expenseCategory-home');

        await pick(tester, 0, 1);

        final texts = cardTexts(tester);
        expect(texts, contains('1 payment · €120.00'));
        expect(texts.where((t) => t == 'Home'), isEmpty);
        expect(texts.first, startsWith('Home · '));
      });

      testWidgets('a tag\'s list names each payment\'s category', (
        tester,
      ) async {
        await _pump(tester, _fixture());
        await _tapRow(tester, 'tag-renovation');

        await pick(tester, 0, 1);

        expect(cardTexts(tester), containsAllInOrder(['Home', '€120.00']));
      });

      testWidgets('another dot switches the list; the same dot again closes '
          'it', (tester) async {
        await _pump(tester, _fixture());

        await pick(tester, 0, 2);
        await pick(tester, 1, 2);
        expect(cardTexts(tester), contains('1 payment · €2,000.00'));

        await pick(tester, 1, 2);
        expect(paymentsCard, findsNothing);
        expect(
          tester.widget<StatsLineChart>(find.byType(StatsLineChart)).selected,
          isNull,
        );
      });

      testWidgets('the close button closes the list', (tester) async {
        await _pump(tester, _fixture());
        await pick(tester, 0, 2);

        await tester.tap(find.byKey(const ValueKey('stats-payments-close')));
        await tester.pumpAndSettle();

        expect(paymentsCard, findsNothing);
      });

      testWidgets('unticking the subject closes the list for good', (
        tester,
      ) async {
        await _pump(tester, _fixture());
        await _tapRow(tester, 'expenseCategory-groceries');
        await pick(tester, 0, 2);
        expect(paymentsCard, findsOneWidget);

        // Ticking another subject keeps the list.
        await _tapRow(tester, 'expenseCategory-home');
        expect(paymentsCard, findsOneWidget);

        await _tapRow(tester, 'expenseCategory-groceries');
        expect(paymentsCard, findsNothing);
        await _tapRow(tester, 'expenseCategory-groceries');
        expect(paymentsCard, findsNothing);
      });

      testWidgets('ticking a subject in place of All closes All\'s list', (
        tester,
      ) async {
        await _pump(tester, _fixture());
        await pick(tester, 0, 2);

        await _tapRow(tester, 'expenseCategory-groceries');
        expect(paymentsCard, findsNothing);
        await _tapRow(tester, 'all-');
        expect(paymentsCard, findsNothing);
      });

      testWidgets('a range leaving the period out closes the list for good', (
        tester,
      ) async {
        await _pump(tester, _fixture());
        await pick(tester, 0, 2);

        // A range still holding the period keeps the list.
        await _openRangeDialog(tester);
        await _chooseFromTo(tester);
        await _pickMonth(tester, 'stats-range-from', oldest);
        await _apply(tester);
        expect(paymentsCard, findsOneWidget);

        await _openRangeDialog(tester);
        await _pickMonth(tester, 'stats-range-to', oldest);
        await _apply(tester);
        expect(paymentsCard, findsNothing);

        await _openRangeDialog(tester);
        await tester.tap(find.text('All periods').last);
        await tester.pumpAndSettle();
        await _apply(tester);
        expect(paymentsCard, findsNothing);
      });

      testWidgets('lays out in a narrow window without overflow', (
        tester,
      ) async {
        await _pump(tester, _fixture(), size: const Size(680, 800));
        await pick(tester, 0, 2);

        expect(tester.takeException(), isNull);
        expect(paymentsCard, findsOneWidget);
      });

      testWidgets('builds under the light theme', (tester) async {
        await _pump(tester, _fixture(), theme: AppTheme.lightTheme);
        await pick(tester, 0, 2);

        expect(tester.takeException(), isNull);
        expect(paymentsCard, findsOneWidget);
      });
    });

    testWidgets('the legend shows each line\'s total over the periods shown', (
      tester,
    ) async {
      await _pump(tester, _fixture());
      Finder legend(int line) => find.byKey(ValueKey('stats-legend-$line'));

      expect(
        find.descendant(of: legend(0), matching: find.text('510')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: legend(1), matching: find.text('6,000')),
        findsOneWidget,
      );

      await _openRangeDialog(tester);
      await _chooseFromTo(tester);
      await _pickMonth(tester, 'stats-range-from', newest);
      await _apply(tester);

      expect(
        find.descendant(of: legend(0), matching: find.text('170')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: legend(1), matching: find.text('2,000')),
        findsOneWidget,
      );
    });

    testWidgets('builds under the light theme', (tester) async {
      await _pump(tester, _fixture(), theme: AppTheme.lightTheme);

      expect(tester.takeException(), isNull);
      expect(find.byType(StatsLineChart), findsOneWidget);
    });
  });
}
