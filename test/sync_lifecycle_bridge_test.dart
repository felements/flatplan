import 'package:flatplan/src/components/sync_lifecycle_bridge.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/sync/conflict_policy.dart';
import 'package:flatplan/src/sync/sync_engine.dart';
import 'package:flatplan/src/sync/sync_journal.dart';
import 'package:flatplan/src/sync/sync_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'sync/in_memory_remote_store.dart';

void main() {
  testWidgets('pausing the app pushes pending changes', (tester) async {
    final files = <String, String>{};
    final journal = SyncJournal();
    final remote = InMemoryRemoteStore();
    final scheduler = SyncScheduler(
      engine: SyncEngine(
        mirror: MemoryWorkspace(files: files),
        remote: remote,
        journal: journal,
        policy: periodConflictPolicy,
      ),
      onStatus: (_) {},
      idleDelay: const Duration(hours: 1),
    );
    journal.onDirty = scheduler.noteChange;
    final workspace = MemoryWorkspace(files: files, changeListener: journal);
    final vault = Vault(
      id: 'r',
      name: 'Remote',
      location: const VaultLocation.remote(kind: 'memory'),
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openVaultProvider.overrideWith(
            (ref) async => OpenVault(
              vault: vault,
              workspace: workspace,
              scheduler: scheduler,
            ),
          ),
        ],
        child: const MaterialApp(
          home: SyncLifecycleBridge(child: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await workspace.writeString('a.yaml', 'a');
    expect(remote.files, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(remote.files.keys, ['a.yaml']);
    scheduler.dispose();
  });
}
