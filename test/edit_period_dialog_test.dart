import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/views/dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/fake_vaults.dart';

/// A vault whose reads take a while, as a real disk or a large vault does.
class _SlowWorkspace extends MemoryWorkspace {
  @override
  Future<String> readString(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return super.readString(name);
  }
}

Period _period(String id, String name, DateTime start) => Period(
  id: id,
  name: name,
  startDate: start,
  baseCurrency: 'EUR',
  lastModified: DateTime(2026, 1, 1),
);

void main() {
  final vault = Vault(
    id: 'v',
    name: 'Home',
    location: const VaultLocation.local(path: '/home'),
    createdAt: DateTime.utc(2026, 1, 1),
  );

  late MemoryWorkspace workspace;

  /// Three September periods; the tests edit the middle one, `b`, unless
  /// they open the current-period dashboard, which shows the last one.
  Future<void> pumpDashboard(
    WidgetTester tester, {
    String? periodId,
    bool slowReads = false,
  }) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    workspace = slowReads ? _SlowWorkspace() : MemoryWorkspace();
    final repo = PeriodRepository(workspace: workspace);
    await repo.savePeriod(
      _period('a', 'Early September', DateTime(2026, 9, 1)),
    );
    await repo.savePeriod(_period('b', 'Mid September', DateTime(2026, 9, 10)));
    await repo.savePeriod(
      _period('c', 'Late September', DateTime(2026, 9, 20)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultsProvider.overrideWith(
            () => FakeVaults(
              VaultRegistry(lastSelectedVaultId: 'v', vaults: [vault]),
            ),
          ),
          openVaultProvider.overrideWith(
            (ref) async => OpenVault(vault: vault, workspace: workspace),
          ),
          periodRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: MaterialApp(
          // The test font renders every glyph as a full square, which makes
          // "Manage Categories" overflow its menu row; the real Outfit face
          // is far narrower.
          theme: ThemeData(
            popupMenuTheme: const PopupMenuThemeData(
              labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 10)),
            ),
          ),
          home: DashboardView(periodId: periodId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openEditDialog(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Period actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Period'));
    await tester.pumpAndSettle();
  }

  /// Opens the start-date picker from the dialog, taps [day] in the shown
  /// month and confirms.
  Future<void> pickDay(WidgetTester tester, String current, int day) async {
    await tester.tap(find.text(current));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('$day'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<Period> readBack(String id) async => (await PeriodRepository(
    workspace: workspace,
  ).loadAllPeriods()).singleWhere((p) => p.id == id);

  Finder saveButton() => find.widgetWithText(ElevatedButton, 'Save');

  testWidgets('Edit Period sits directly above Manage Categories', (
    tester,
  ) async {
    await pumpDashboard(tester, periodId: 'b');

    await tester.tap(find.byTooltip('Period actions'));
    await tester.pumpAndSettle();

    final edit = tester.getCenter(find.text('Edit Period'));
    final manage = tester.getCenter(find.text('Manage Categories'));
    expect(edit.dy, lessThan(manage.dy));
  });

  testWidgets('the dialog opens on the period\'s name and start date', (
    tester,
  ) async {
    await pumpDashboard(tester, periodId: 'b');
    await openEditDialog(tester);

    expect(find.widgetWithText(TextField, 'Mid September'), findsOneWidget);
    expect(find.text('Sep 10, 2026'), findsOneWidget);
  });

  testWidgets('Save is disabled while the name is empty', (tester) async {
    await pumpDashboard(tester, periodId: 'b');
    await openEditDialog(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    expect(tester.widget<ElevatedButton>(saveButton()).onPressed, isNull);
  });

  testWidgets('a start date past the next period warns and names it', (
    tester,
  ) async {
    await pumpDashboard(tester, periodId: 'b');
    await openEditDialog(tester);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

    await pickDay(tester, 'Sep 10, 2026', 25);

    expect(find.text('Sep 25, 2026'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.textContaining('"Late September"'), findsOneWidget);
  });

  testWidgets('another period\'s start day cannot be picked', (tester) async {
    await pumpDashboard(tester, periodId: 'b');
    await openEditDialog(tester);

    // `c` starts on the 20th; the tap must not select it.
    await pickDay(tester, 'Sep 10, 2026', 20);

    expect(find.text('Sep 10, 2026'), findsOneWidget);
    expect(find.text('Sep 20, 2026'), findsNothing);
  });

  testWidgets('Save stores the new name and start date', (tester) async {
    await pumpDashboard(tester, periodId: 'b');
    await openEditDialog(tester);

    await tester.enterText(find.byType(TextField), 'Payday to payday');
    await pickDay(tester, 'Sep 10, 2026', 15);
    // Still between its neighbours, so nothing to warn about.
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Payday to payday'), findsOneWidget);
    final saved = await readBack('b');
    expect(saved.name, 'Payday to payday');
    expect(saved.startDate, DateTime(2026, 9, 15));
  });

  testWidgets('Save reaches a vault that is slow to read', (tester) async {
    // Nothing on the dashboard watches the period's own notifier. Unless the
    // dialog holds it, it is disposed while still loading the period and
    // the save is lost.
    await pumpDashboard(tester, periodId: 'b', slowReads: true);
    await openEditDialog(tester);

    await tester.enterText(find.byType(TextField), 'Payday to payday');
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(() => readBack('b'));
    expect(saved!.name, 'Payday to payday');
  });

  testWidgets('Save on the current-period dashboard updates its header', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(find.text('Late September'), findsOneWidget);
    await openEditDialog(tester);

    await tester.enterText(find.byType(TextField), 'Autumn');
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.text('Autumn'), findsOneWidget);
    expect(find.text('Late September'), findsNothing);
  });

  testWidgets('Save with nothing changed leaves the file alone', (
    tester,
  ) async {
    await pumpDashboard(tester, periodId: 'b');
    await openEditDialog(tester);

    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect((await readBack('b')).lastModified, DateTime(2026, 1, 1));
  });
}
