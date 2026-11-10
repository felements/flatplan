import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flatplan/src/components/summary_card.dart';
import 'package:flatplan/src/components/tag_chip.dart';
import 'package:flatplan/src/components/top_tags_card.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/views/category_detail_view.dart';
import 'package:flatplan/src/views/dashboard_view.dart';

DateTime _midnightDaysAgo(int days) {
  final d = DateTime.now().subtract(Duration(days: days));
  return DateTime(d.year, d.month, d.day);
}

FactExpense _fact(String id, double amount, [String? description]) =>
    FactExpense(
      id: id,
      amount: amount,
      description: description,
      timestamp: _midnightDaysAgo(1).add(const Duration(hours: 12)),
    );

Period _period(String id, int startDaysAgo, List<Category> categories) =>
    Period(
      id: id,
      name: id,
      startDate: _midnightDaysAgo(startDaysAgo),
      baseCurrency: 'EUR',
      lastModified: _midnightDaysAgo(startDaysAgo),
      categories: categories,
    );

Category _home(List<FactExpense> facts) => Category(
  id: 'home',
  name: 'Home',
  type: CategoryType.optionalExpense,
  limit: 5000,
  factExpenses: facts,
);

Future<PeriodRepository> _repoWith(List<Period> periods) async {
  final repo = PeriodRepository(workspace: MemoryWorkspace());
  for (final period in periods) {
    await repo.savePeriod(period);
  }
  return repo;
}

Future<void> _pump(
  WidgetTester tester,
  PeriodRepository repo,
  Widget home, {
  Size size = const Size(2400, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.runAsync(() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
        child: MaterialApp(home: home),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
  });
}

Finder _chip(String tag) =>
    find.descendant(of: find.byType(TagChip), matching: find.text(tag));

Finder _inTopTags(String text) =>
    find.descendant(of: find.byType(TopTagsCard), matching: find.text(text));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('category screen', () {
    testWidgets('a payment comment shows its tags as chips after the text', (
      tester,
    ) async {
      final repo = await _repoWith([
        _period('current', 5, [
          _home([_fact('f1', 120, 'something #tws in alza #renovation')]),
        ]),
      ]);
      await _pump(
        tester,
        repo,
        const CategoryDetailView(categoryId: 'home', periodId: 'current'),
        size: const Size(1400, 1800),
      );

      expect(find.text('something in alza'), findsOneWidget);
      expect(_chip('tws'), findsOneWidget);
      expect(_chip('renovation'), findsOneWidget);
      expect(find.textContaining('#'), findsNothing);
      expect(
        tester.getTopLeft(_chip('tws')).dx,
        lessThan(tester.getTopLeft(_chip('renovation')).dx),
      );
    });

    testWidgets('a comment made only of tags shows just the chips', (
      tester,
    ) async {
      final repo = await _repoWith([
        _period('current', 5, [
          _home([_fact('f1', 120, '#renovation')]),
        ]),
      ]);
      await _pump(
        tester,
        repo,
        const CategoryDetailView(categoryId: 'home', periodId: 'current'),
        size: const Size(1400, 1800),
      );

      expect(_chip('renovation'), findsOneWidget);
      expect(find.text('No comment'), findsNothing);
    });
  });

  group('dashboard', () {
    testWidgets('the Top tags card sums each tag in the period and overall', (
      tester,
    ) async {
      final repo = await _repoWith([
        _period('older', 40, [
          _home([_fact('o1', 500, '#renovation')]),
        ]),
        _period('current', 5, [
          _home([
            _fact('c1', 100, 'tiles #renovation #tws'),
            _fact('c2', 30, 'paint #renovation'),
          ]),
        ]),
      ]);
      await _pump(tester, repo, const DashboardView(periodId: 'current'));

      expect(find.byType(TopTagsCard), findsOneWidget);
      expect(_inTopTags('Top tags'), findsOneWidget);
      // renovation: 130 this period, 630 with the older period.
      expect(_inTopTags('130'), findsOneWidget);
      expect(_inTopTags('630'), findsOneWidget);
      // tws: 100 in both columns.
      expect(_inTopTags('100'), findsNWidgets(2));
      expect(
        tester.getTopLeft(_chip('renovation')).dy,
        lessThan(tester.getTopLeft(_chip('tws')).dy),
      );
    });

    testWidgets('the Top tags card is as tall as the summary cards', (
      tester,
    ) async {
      final repo = await _repoWith([
        _period('current', 5, [
          _home([
            for (var i = 1; i <= 8; i++)
              _fact('f$i', i * 1000.0, '#tag$i #renovation_long_name'),
          ]),
        ]),
      ]);
      await _pump(tester, repo, const DashboardView(periodId: 'current'));

      final summaryHeight = tester
          .getSize(find.byType(SummaryCard).first)
          .height;
      final tagsHeight = tester.getSize(find.byType(TopTagsCard)).height;
      expect(tagsHeight, lessThanOrEqualTo(summaryHeight));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Top tags card is hidden when nothing is tagged', (
      tester,
    ) async {
      final repo = await _repoWith([
        _period('current', 5, [
          _home([_fact('c1', 100, 'bread')]),
        ]),
      ]);
      await _pump(tester, repo, const DashboardView(periodId: 'current'));

      expect(find.text('Total Spent (fact)'), findsOneWidget);
      expect(find.byType(TopTagsCard), findsNothing);
    });
  });
}
