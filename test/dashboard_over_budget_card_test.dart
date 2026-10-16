import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flatplan/src/components/summary_card.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/views/dashboard_view.dart';

DateTime _midnightDaysAgo(int days) {
  final d = DateTime.now().subtract(Duration(days: days));
  return DateTime(d.year, d.month, d.day);
}

FactExpense _fact(String id, double amount) => FactExpense(
  id: id,
  amount: amount,
  timestamp: _midnightDaysAgo(1).add(const Duration(hours: 12)),
);

Future<void> _pumpDashboard(WidgetTester tester, PeriodRepository repo) async {
  tester.view.physicalSize = const Size(2400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.runAsync(() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
        child: const MaterialApp(home: DashboardView(periodId: 'current')),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
  });
}

/// The amount shown on the Over Budget card alone, so figures on the other
/// cards (such as a zero planned income) cannot stand in for it.
Finder _overBudgetAmount(String pattern) => find.descendant(
  of: find.ancestor(
    of: find.text('Over Budget'),
    matching: find.byType(SummaryCard),
  ),
  matching: find.textContaining(RegExp(pattern)),
);

Future<PeriodRepository> _repoWith(List<Category> categories) async {
  final repo = PeriodRepository(workspace: MemoryWorkspace());
  await repo.savePeriod(
    Period(
      id: 'current',
      name: 'Current',
      startDate: _midnightDaysAgo(5),
      baseCurrency: 'EUR',
      lastModified: _midnightDaysAgo(5),
      categories: categories,
    ),
  );
  return repo;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the Over Budget card sums only the categories over limit', (
    tester,
  ) async {
    final repo = await _repoWith([
      // 70 over.
      Category(
        id: 'fun',
        name: 'Fun',
        type: CategoryType.optionalExpense,
        limit: 100,
        factExpenses: [_fact('f1', 170)],
      ),
      // 150 under, which must not shrink the figure.
      Category(
        id: 'groceries',
        name: 'Groceries',
        type: CategoryType.optionalExpense,
        limit: 200,
        factExpenses: [_fact('g1', 50)],
      ),
    ]);
    await _pumpDashboard(tester, repo);

    expect(find.text('Over Budget'), findsOneWidget);
    expect(_overBudgetAmount(r'^\D*70$'), findsOneWidget);
    expect(find.text('1 of 2 categories over limit'), findsOneWidget);
  });

  testWidgets('the Over Budget card reads zero when nothing is over', (
    tester,
  ) async {
    final repo = await _repoWith([
      Category(
        id: 'fun',
        name: 'Fun',
        type: CategoryType.optionalExpense,
        limit: 100,
        factExpenses: [_fact('f1', 40)],
      ),
    ]);
    await _pumpDashboard(tester, repo);

    expect(find.text('Over Budget'), findsOneWidget);
    expect(_overBudgetAmount(r'^\D*0$'), findsOneWidget);
    expect(find.text('all categories within limit'), findsOneWidget);
  });
}
