import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/views/category_detail_view.dart';

DateTime _midnightDaysAgo(int days) {
  final d = DateTime.now().subtract(Duration(days: days));
  return DateTime(d.year, d.month, d.day);
}

FactExpense _fact(String id, double amount, int daysAgo) => FactExpense(
  id: id,
  amount: amount,
  timestamp: _midnightDaysAgo(daysAgo).add(const Duration(hours: 12)),
);

Category _groceries({
  required String id,
  List<FactExpense> facts = const [],
  double? bigPurchaseThreshold,
}) => Category(
  id: id,
  name: 'Groceries',
  type: CategoryType.optionalExpense,
  limit: 14000,
  isDailyAllowance: true,
  bigPurchaseThreshold: bigPurchaseThreshold,
  factExpenses: facts,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PeriodRepository repo;

  setUp(() async {
    repo = PeriodRepository(workspace: MemoryWorkspace());

    // Two complete prior periods, each mixing small (<500) and basket-sized
    // (>=500) purchases — basketStatsFor needs a basket in every period in
    // its window, or it returns null. Mirrors the fixture shape in
    // test/basket_stats_test.dart.
    await repo.savePeriod(
      Period(
        id: 'older',
        name: 'Older',
        startDate: _midnightDaysAgo(62),
        baseCurrency: 'EUR',
        lastModified: _midnightDaysAgo(62),
        categories: [
          _groceries(
            id: 'older-groceries',
            facts: [
              _fact('a1', 100, 60),
              _fact('a2', 100, 55),
              _fact('a3', 1000, 50),
              _fact('a4', 1000, 45),
            ],
          ),
        ],
      ),
    );

    await repo.savePeriod(
      Period(
        id: 'previous',
        name: 'Previous',
        startDate: _midnightDaysAgo(32),
        baseCurrency: 'EUR',
        lastModified: _midnightDaysAgo(32),
        categories: [
          _groceries(
            id: 'old-groceries',
            facts: [
              _fact('o1', 100, 28),
              _fact('o2', 200, 22),
              _fact('o3', 300, 16),
              _fact('o4', 600, 10),
              _fact('o5', 1400, 5),
            ],
          ),
        ],
      ),
    );

    await repo.savePeriod(
      Period(
        id: 'current',
        name: 'Current',
        startDate: _midnightDaysAgo(2),
        baseCurrency: 'EUR',
        lastModified: _midnightDaysAgo(2),
        categories: [
          _groceries(id: 'new-groceries', bigPurchaseThreshold: 500),
        ],
      ),
    );
  });

  testWidgets('detail view shows the pace suggestion for a daily allowance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The providers read real files, so the whole load has to run on the
    // real clock rather than the test's fake one.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
          child: const MaterialApp(
            home: CategoryDetailView(
              periodId: 'current',
              categoryId: 'new-groceries',
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    });

    expect(find.textContaining('safe per shop'), findsOneWidget);
    expect(
      find.textContaining('Reserved for small purchases'),
      findsOneWidget,
    );
    // The trip count carries a decimal, so the safe-per-shop figure can be
    // divided out by hand rather than disagreeing with a rounded count.
    expect(
      find.textContaining(RegExp(r'across \d+\.\d shops')),
      findsOneWidget,
    );
  });
}
