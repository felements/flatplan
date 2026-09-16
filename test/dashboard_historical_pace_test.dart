import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/views/dashboard_view.dart';

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
  required double limit,
  List<FactExpense> facts = const [],
}) => Category(
  id: id,
  name: 'Groceries',
  type: CategoryType.optionalExpense,
  limit: limit,
  isDailyAllowance: true,
  factExpenses: facts,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PeriodRepository repo;

  setUp(() async {
    repo = PeriodRepository(workspace: MemoryWorkspace());

    // One period older still, so the finished period below has history of
    // its own to price a trend from. Without it, the closed-period rule
    // would not be the only thing suppressing the insight and the
    // assertion in the first test would prove nothing.
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
            limit: 14000,
            facts: [
              _fact('x1', 1000, 60),
              _fact('x2', 1000, 50),
              _fact('x3', 1000, 40),
            ],
          ),
        ],
      ),
    );

    // The finished period being browsed: steady 1000-a-visit grocery runs.
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
            limit: 14000,
            facts: [
              _fact('o1', 1000, 30),
              _fact('o2', 1000, 25),
              _fact('o3', 1000, 20),
              _fact('o4', 1000, 15),
            ],
          ),
        ],
      ),
    );

    // The live period, with much bigger purchases the old period never saw.
    await repo.savePeriod(
      Period(
        id: 'current',
        name: 'Current',
        startDate: _midnightDaysAgo(2),
        baseCurrency: 'EUR',
        lastModified: _midnightDaysAgo(2),
        categories: [
          _groceries(
            id: 'new-groceries',
            limit: 14000,
            facts: [_fact('n1', 9000, 1), _fact('n2', 9000, 0)],
          ),
        ],
      ),
    );
  });

  testWidgets('a finished period suggests no spending cadence', (tester) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
          child: const MaterialApp(home: DashboardView(periodId: 'previous')),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    });

    // The period is over, so there is nothing left to pace: neither
    // insight is offered, even though the period before it carries the
    // history a trend would be priced from, and in particular none
    // priced on the 9000 runs booked after it ended.
    expect(find.textContaining('safe per shop'), findsNothing);
    expect(find.textContaining('averaging'), findsNothing);
    expect(find.textContaining('/ day left'), findsOneWidget);
  });

  testWidgets('a live period prices its trend off the period before it', (
    tester,
  ) async {
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

    // The other side of the rule above, and the only coverage that runs
    // the trend from disk through the providers to the tile: 4,000 over
    // the previous period's 30 days is 133 a day, and 18,000 already
    // spent against a 14,000 limit makes it a projected overshoot.
    expect(
      find.textContaining(RegExp(r'averaging \D*133/day')),
      findsOneWidget,
    );
    expect(find.textContaining('heading'), findsOneWidget);
    // No threshold is set on either period, so the basket insight stays
    // off and the daily figure leads.
    expect(find.textContaining('safe per shop'), findsNothing);
  });
}
