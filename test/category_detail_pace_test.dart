import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
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
}) => Category(
  id: id,
  name: 'Groceries',
  type: CategoryType.optionalExpense,
  limit: 14000,
  isDailyAllowance: true,
  factExpenses: facts,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PeriodRepository repo;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('flatplan_detail_pace_');
    repo = PeriodRepository(directoryPath: tempDir.path);

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
              _fact('o1', 1000, 20),
              _fact('o2', 1000, 15),
              _fact('o3', 1000, 10),
              _fact('o4', 1000, 5),
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
        categories: [_groceries(id: 'new-groceries')],
      ),
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
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

    expect(find.textContaining('every 2 days'), findsOneWidget);
  });
}
