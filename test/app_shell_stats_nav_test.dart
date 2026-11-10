import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/views/app_shell.dart';
import 'package:flatplan/src/views/stats_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_vaults.dart';
import 'support/stats_fixtures.dart';

void main() {
  final vault = Vault(
    id: 'v',
    name: 'Home',
    location: const VaultLocation.local(path: '/home'),
    createdAt: DateTime.utc(2026, 1, 1),
  );

  /// A period that spans today, with a category to tick on the Stats page.
  Period activePeriod() {
    final start = DateTime.now().subtract(const Duration(days: 5));
    return period('p1', DateTime(start.year, start.month, start.day), [
      category('Groceries', limit: 400, facts: [(50, null)]),
    ]);
  }

  /// The sidebar's Stats item, not the page's own "Stats" heading.
  Finder statsItem() => find.widgetWithText(InkWell, 'Stats');

  /// Pumps the shell over the app's branch layout (Today, Settings, Stats),
  /// with [stats] standing in for the Stats page.
  Future<void> pumpShell(
    WidgetTester tester, {
    List<Period> periods = const [],
    Widget stats = const Text('stats page'),
  }) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final repo = PeriodRepository(workspace: MemoryWorkspace());
    for (final p in periods) {
      await repo.savePeriod(p);
    }

    final router = GoRouter(
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const Placeholder()),
                GoRoute(
                  path: '/period/:id',
                  builder: (_, _) => const Placeholder(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (_, _) => const Placeholder(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [GoRoute(path: '/stats', builder: (_, _) => stats)],
            ),
          ],
        ),
      ],
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultsProvider.overrideWith(
              () => FakeVaults(
                VaultRegistry(lastSelectedVaultId: 'v', vaults: [vault]),
              ),
            ),
            openVaultProvider.overrideWith(
              (ref) async =>
                  OpenVault(vault: vault, workspace: MemoryWorkspace()),
            ),
            periodRepositoryProvider.overrideWith((ref) => repo),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            // The test font renders every glyph as a full square, which makes
            // the branding title overflow the 220 px sidebar; the real Outfit
            // face is far narrower.
            theme: ThemeData(
              textTheme: const TextTheme(titleLarge: TextStyle(fontSize: 14)),
            ),
          ),
        ),
      );
      // The period files are read in real time.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    });
    await tester.pumpAndSettle();
  }

  testWidgets('Stats sits under Today, above Next period, and opens the stats '
      'page', (tester) async {
    await pumpShell(tester, periods: [activePeriod()]);

    final today = tester.getTopLeft(find.text('Today')).dy;
    final stats = tester.getTopLeft(find.text('Stats')).dy;
    final nextPeriod = tester
        .getTopLeft(find.widgetWithText(OutlinedButton, 'Next period'))
        .dy;
    expect(today, lessThan(stats));
    expect(stats, lessThan(nextPeriod));
    expect(find.text('stats page'), findsNothing);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    expect(find.text('stats page'), findsOneWidget);
  });

  testWidgets('the Stats page keeps its ticks while another branch is open', (
    tester,
  ) async {
    await pumpShell(
      tester,
      periods: [activePeriod()],
      stats: const StatsView(),
    );

    final groceries = find.byKey(
      const ValueKey('stats-subject-expenseCategory-groceries'),
    );
    bool ticked() => tester
        .widget<Checkbox>(
          find.descendant(of: groceries, matching: find.byType(Checkbox)),
        )
        .value!;

    await tester.tap(statsItem());
    await tester.pumpAndSettle();
    expect(ticked(), isFalse);
    await tester.tap(groceries);
    await tester.pumpAndSettle();
    expect(ticked(), isTrue);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(
      GoRouter.of(tester.element(find.text('Settings'))).state.uri.path,
      '/settings',
    );

    await tester.tap(statsItem());
    await tester.pumpAndSettle();
    expect(
      GoRouter.of(tester.element(find.text('Settings'))).state.uri.path,
      '/stats',
    );
    expect(ticked(), isTrue);
  });
}
