import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flatplan/src/components/category_dialog.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/all_periods_provider.dart';
import 'package:flatplan/src/providers/period_notifier_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';

void main() {
  testWidgets('offers a big-purchase threshold once daily allowance is on', (
    tester,
  ) async {
    final repo = PeriodRepository(workspace: MemoryWorkspace());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showCategoryDialog(
                    context,
                    ref,
                    const Category(
                      id: 'c1',
                      name: 'Groceries',
                      isDailyAllowance: true,
                    ),
                    periodId: 'p1',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Big-purchase threshold'), findsOneWidget);
  });

  testWidgets(
    'does not offer a big-purchase threshold when daily allowance is off',
    (tester) async {
      final repo = PeriodRepository(workspace: MemoryWorkspace());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showCategoryDialog(
                      context,
                      ref,
                      const Category(
                        id: 'c1',
                        name: 'Groceries',
                        isDailyAllowance: false,
                      ),
                      periodId: 'p1',
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Big-purchase threshold'), findsNothing);
    },
  );

  testWidgets(
    'toggling the allowance off before saving writes a null threshold',
    (tester) async {
      // The dialog's content column is tall enough that the default test
      // surface clips/scrolls it, which makes tapping the switch unreliable.
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = PeriodRepository(workspace: MemoryWorkspace());

      final period = Period(
        id: 'p1',
        name: 'P1',
        startDate: DateTime(2026, 1, 1),
        baseCurrency: 'EUR',
        lastModified: DateTime(2026, 1, 1),
        categories: const [
          Category(
            id: 'c1',
            name: 'Groceries',
            isDailyAllowance: true,
            bigPurchaseThreshold: 500,
          ),
        ],
      );

      late WidgetRef capturedRef;

      // periodRepositoryProvider does real file I/O, which needs the real
      // event loop rather than the fake one testWidgets runs on by default —
      // see test/category_detail_pace_test.dart for the same pattern. All of
      // it, including the initial save, has to live inside runAsync: doing
      // the save outside of it deadlocks the test instead of just failing.
      await tester.runAsync(() async {
        await repo.savePeriod(period);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  // Warm up the real (file-backed) provider before
                  // interacting with the dialog; a bare `ref.read` at
                  // dialog-open time would otherwise still be loading.
                  ref.watch(periodProvider('p1'));
                  return Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => showCategoryDialog(
                          context,
                          ref,
                          period.categories.first,
                          periodId: 'p1',
                        ),
                        child: const Text('open'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();

        // Sanity: the provider actually loaded the saved period.
        expect(capturedRef.read(periodProvider('p1')).value?.id, 'p1');
      });

      await tester.tap(find.text('open'));
      await tester.pump();

      // isDailyAllowance starts true (from `existing`) -> field is visible.
      expect(find.text('Big-purchase threshold'), findsOneWidget);

      // Turn allowance off; the field should hide immediately.
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(find.text('Big-purchase threshold'), findsNothing);

      await tester.tap(find.text('Save'));
      await tester.pump();

      final updated = capturedRef.read(periodProvider('p1')).value;
      final cat = updated!.categories.first;
      expect(cat.isDailyAllowance, isFalse);
      expect(cat.bigPurchaseThreshold, isNull);

      // Saving schedules PeriodNotifier's debounced-save Timer; advance past
      // its 500ms delay so it fires (and the test doesn't end with a timer
      // still pending).
      await tester.pump(const Duration(milliseconds: 600));
    },
  );

  testWidgets(
    'saving an untouched field leaves the threshold null despite a suggestion',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = PeriodRepository(workspace: MemoryWorkspace());

      // A prior period rich enough for a suggestion to exist: the mean of
      // [100, 100, 1000, 1000] is 550, rounded to the nearest 50. The field
      // used to be pre-filled with exactly that, so an untouched Save wrote
      // an inferred threshold the user never chose.
      final previous = Period(
        id: 'p0',
        name: 'P0',
        startDate: DateTime(2026, 1, 1),
        baseCurrency: 'EUR',
        lastModified: DateTime(2026, 1, 1),
        categories: [
          Category(
            id: 'c0',
            name: 'Groceries',
            isDailyAllowance: true,
            factExpenses: [
              for (final amount in const [100.0, 100.0, 1000.0, 1000.0])
                FactExpense(
                  id: 'f$amount',
                  amount: amount,
                  timestamp: DateTime(2026, 1, 2),
                ),
            ],
          ),
        ],
      );
      final period = Period(
        id: 'p1',
        name: 'P1',
        startDate: DateTime(2026, 2, 1),
        baseCurrency: 'EUR',
        lastModified: DateTime(2026, 2, 1),
        categories: const [
          Category(id: 'c1', name: 'Groceries', isDailyAllowance: true),
        ],
      );

      late WidgetRef capturedRef;

      // Real file I/O needs the real event loop — same pattern as the test
      // above, including doing the initial saves inside runAsync.
      await tester.runAsync(() async {
        await repo.savePeriod(previous);
        await repo.savePeriod(period);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  // Both providers the dialog reads have to be warm, or the
                  // suggestion would be absent for the wrong reason.
                  ref.watch(periodProvider('p1'));
                  ref.watch(allPeriodsProvider);
                  return Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => showCategoryDialog(
                          context,
                          ref,
                          period.categories.first,
                          periodId: 'p1',
                        ),
                        child: const Text('open'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();

        // Sanity: both periods are on hand, so a suggestion is computable.
        expect(capturedRef.read(allPeriodsProvider).value, hasLength(2));
      });

      await tester.tap(find.text('open'));
      await tester.pump();

      // The suggestion is offered as guidance...
      expect(
        find.textContaining('Suggested from your history: 550'),
        findsOneWidget,
      );
      // ...but it never reaches the field.
      final field = tester
          .widgetList<TextField>(find.byType(TextField))
          .firstWhere(
            (f) => f.decoration?.labelText == 'Big-purchase threshold',
          );
      expect(field.controller!.text, isEmpty);

      await tester.tap(find.text('Save'));
      await tester.pump();

      final updated = capturedRef.read(periodProvider('p1')).value;
      final cat = updated!.categories.first;
      expect(cat.isDailyAllowance, isTrue);
      expect(cat.bigPurchaseThreshold, isNull);

      // Let PeriodNotifier's debounced save fire before the test ends.
      await tester.pump(const Duration(milliseconds: 600));
    },
  );
}
