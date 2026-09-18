import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/views/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_vaults.dart';

void main() {
  final vault = Vault(
    id: 'v',
    name: 'Home',
    location: const VaultLocation.local(path: '/home'),
    createdAt: DateTime.utc(2026, 1, 1),
  );

  /// A period that spans today, so it becomes the current period.
  Period activePeriod() {
    final start = DateTime.now().subtract(const Duration(days: 5));
    return Period(
      id: 'p1',
      name: 'This Month',
      startDate: DateTime(start.year, start.month, start.day),
      baseCurrency: 'EUR',
      lastModified: DateTime(2026, 1, 1),
      categories: const [],
    );
  }

  Future<void> pumpShell(
    WidgetTester tester, {
    List<Period> periods = const [],
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
          ],
        ),
      ],
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
    await tester.pumpAndSettle();
  }

  testWidgets('sidebar shows a wide outlined Next period button under Today', (
    tester,
  ) async {
    await pumpShell(tester, periods: [activePeriod()]);

    expect(find.text('Periods'), findsNothing);
    final buttonFinder = find.widgetWithText(OutlinedButton, 'Next period');
    final button = tester.widget<OutlinedButton>(buttonFinder);
    final shape = button.style?.shape?.resolve({}) as RoundedRectangleBorder?;
    expect(shape?.borderRadius, BorderRadius.circular(12));

    // Spans the sidebar like the nav items (220 px minus 12 px each side)
    // and sits between Today and the first period.
    expect(tester.getSize(buttonFinder).width, closeTo(196, 1));
    final todayBottom = tester.getBottomLeft(find.text('Today')).dy;
    final buttonTop = tester.getTopLeft(buttonFinder).dy;
    final firstLabel = DateFormat('MMM yy').format(activePeriod().startDate);
    final firstPeriodTop = tester.getTopLeft(find.text(firstLabel)).dy;
    expect(buttonTop, greaterThan(todayBottom));
    expect(tester.getBottomLeft(buttonFinder).dy, lessThan(firstPeriodTop));
  });

  testWidgets('Next period on an empty vault opens the first-period dialog', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Next period'));
    await tester.pumpAndSettle();

    expect(find.text('Create First Period'), findsOneWidget);
  });

  testWidgets('Next period with a current period opens the generate dialog', (
    tester,
  ) async {
    await pumpShell(tester, periods: [activePeriod()]);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Next period'));
    await tester.pumpAndSettle();

    expect(find.text('Generate Next Period'), findsOneWidget);
  });
}
