import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flatplan/src/components/planned_expense_dialog.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/views/category_detail_view.dart';

DateTime _midnightDaysFromNow(int days) {
  final d = DateTime.now().add(Duration(days: days));
  return DateTime(d.year, d.month, d.day);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final overdueDate = _midnightDaysFromNow(-5);
  final upcomingDate = _midnightDaysFromNow(5);
  final settledDate = _midnightDaysFromNow(-7);
  final forgottenDate = _midnightDaysFromNow(-35);

  late PeriodRepository repo;

  setUp(() async {
    repo = PeriodRepository(workspace: MemoryWorkspace());
    await repo.savePeriod(
      Period(
        id: 'previous',
        name: 'Previous',
        startDate: _midnightDaysFromNow(-40),
        baseCurrency: 'EUR',
        lastModified: _midnightDaysFromNow(-40),
        categories: [
          Category(
            id: 'old-bills',
            name: 'Bills',
            type: CategoryType.mandatoryExpense,
            limit: 1000,
            plannedExpenses: [
              PlannedExpense(
                id: 'old-rent',
                description: 'Rent',
                amount: 600,
                dueDate: DueDate.exact(date: forgottenDate),
              ),
            ],
          ),
        ],
      ),
    );
    await repo.savePeriod(
      Period(
        id: 'current',
        name: 'Current',
        startDate: _midnightDaysFromNow(-10),
        baseCurrency: 'EUR',
        lastModified: _midnightDaysFromNow(-10),
        categories: [
          Category(
            id: 'bills',
            name: 'Bills',
            type: CategoryType.mandatoryExpense,
            limit: 1000,
            plannedExpenses: [
              PlannedExpense(
                id: 'rent',
                description: 'Rent',
                amount: 600,
                dueDate: DueDate.exact(date: overdueDate),
              ),
              PlannedExpense(
                id: 'power',
                description: 'Power',
                amount: 100,
                dueDate: DueDate.exact(date: upcomingDate),
              ),
              PlannedExpense(
                id: 'water',
                description: 'Water',
                amount: 50,
                dueDate: DueDate.exact(date: settledDate),
                isCompleted: true,
              ),
            ],
          ),
        ],
      ),
    );
  });

  Future<void> pumpDetail(
    WidgetTester tester, {
    String periodId = 'current',
    String categoryId = 'bills',
  }) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The providers load through the repository asynchronously, so the
    // whole load runs on the real clock rather than the test's fake one.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            home: CategoryDetailView(
              periodId: periodId,
              categoryId: categoryId,
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    });
  }

  Color? dueLabelColor(WidgetTester tester, DateTime date) {
    final text = tester.widget<Text>(
      find.text(formatDueDate(DueDate.exact(date: date))),
    );
    return text.style?.color;
  }

  testWidgets('an overdue planned payment shows its due day in red', (
    tester,
  ) async {
    await pumpDetail(tester);

    final errorColor = Theme.of(
      tester.element(find.byType(Scaffold)),
    ).colorScheme.error;
    expect(dueLabelColor(tester, overdueDate), errorColor);
  });

  testWidgets('a pending planned payment keeps the muted due day', (
    tester,
  ) async {
    await pumpDetail(tester);

    final errorColor = Theme.of(
      tester.element(find.byType(Scaffold)),
    ).colorScheme.error;
    expect(dueLabelColor(tester, upcomingDate), isNot(errorColor));
  });

  testWidgets('a completed planned payment past its date is not flagged', (
    tester,
  ) async {
    await pumpDetail(tester);

    final errorColor = Theme.of(
      tester.element(find.byType(Scaffold)),
    ).colorScheme.error;
    expect(dueLabelColor(tester, settledDate), isNot(errorColor));
  });

  testWidgets('an unpaid payment in a finished period is not flagged', (
    tester,
  ) async {
    await pumpDetail(tester, periodId: 'previous', categoryId: 'old-bills');

    final errorColor = Theme.of(
      tester.element(find.byType(Scaffold)),
    ).colorScheme.error;
    expect(dueLabelColor(tester, forgottenDate), isNot(errorColor));
  });
}
