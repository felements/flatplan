import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/vault_resolver.dart';
import '../sync/gitlab/gitlab_provider.dart';
import '../sync/remote_store.dart';
import '../sync/sync_status.dart';
import 'all_periods_provider.dart';
import 'app_paths_provider.dart';
import 'current_period_provider.dart';
import 'repository_provider.dart';
import 'vaults_provider.dart';

part 'open_vault_provider.g.dart';

/// Remote kinds this build can open.
@Riverpod(keepAlive: true)
RemoteStoreRegistry remoteStoreRegistry(Ref ref) {
  final registry = RemoteStoreRegistry();
  registerGitLabProvider(registry);
  return registry;
}

@Riverpod(keepAlive: true)
Future<VaultResolver> vaultResolver(Ref ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  return VaultResolver(
    paths: paths,
    remoteStores: ref.watch(remoteStoreRegistryProvider),
    secrets: ref.watch(vaultSecretsProvider),
  );
}

/// Sync status of the open vault. Null for local vaults.
@Riverpod(keepAlive: true)
class CurrentSyncStatus extends _$CurrentSyncStatus {
  @override
  SyncStatus? build() => null;

  void set(SyncStatus? status) => state = status;
}

/// The selected vault, resolved. Re-resolves when the selection changes;
/// the outgoing remote vault gets a best-effort push first.
@Riverpod(keepAlive: true)
Future<OpenVault> openVault(Ref ref) async {
  // Held directly rather than re-read on every tick: the status callback also
  // fires from the outgoing scheduler's flush, which runs inside onDispose
  // where touching `ref` is forbidden.
  final status = ref.read(currentSyncStatusProvider.notifier);
  // Cleared on dispose so the outgoing vault's farewell push cannot overwrite
  // the incoming vault's status.
  var live = true;
  // Registered before the first await: `ref.onDispose` throws once this build
  // is superseded, which would leave a scheduler running and publishing.
  OpenVault? opened;
  ref.onDispose(() {
    live = false;
    final scheduler = opened?.scheduler;
    if (scheduler != null) {
      unawaited(scheduler.flushBeforeSwitch().whenComplete(scheduler.dispose));
    }
  });

  final registry = await ref.watch(vaultsProvider.future);
  final vault = registry.selected;
  if (vault == null) throw StateError('No vault is configured.');

  final resolver = await ref.watch(vaultResolverProvider.future);
  final open = await resolver.open(
    vault,
    onStatus: (value) {
      if (live) status.set(value);
    },
    onMirrorChanged: (names) {
      if (live && ref.mounted) _reloadPeriods(ref.container, names);
    },
  );
  if (!ref.mounted) {
    // A newer selection won while this vault was opening. Nothing has been
    // written through this workspace yet, so there is nothing to flush.
    open.scheduler?.dispose();
    throw StateError('Vault open superseded by a newer selection.');
  }
  opened = open;
  status.set(open.scheduler?.status);

  // Pulls when nothing is dirty; pushes (pulling first) when an interrupted
  // session left changes pending.
  unawaited(open.scheduler?.syncNow());
  return open;
}

/// A pull changed [names] in the mirror the app is reading. The period
/// list always re-reads; the open period is re-read only when it has no
/// value yet or its own file changed, so an edit still waiting for its
/// debounced save is not thrown away over an unrelated file.
///
/// Through the container: these providers depend on [openVaultProvider],
/// and `ref.read` from here would report that as a circular dependency.
void _reloadPeriods(ProviderContainer container, Set<String> names) {
  container.invalidate(periodLoadResultProvider);
  if (!container.exists(currentPeriodProvider)) return;
  final current = container.read(currentPeriodProvider).value;
  final file = current == null
      ? null
      : container.read(periodRepositoryProvider).value?.filenameForPeriod(current.id);
  if (current == null || file == null || names.contains(file)) {
    container.invalidate(currentPeriodProvider);
  }
}
