import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/period_repository.dart';
import 'open_vault_provider.dart';

part 'repository_provider.g.dart';

/// The selected vault cannot be worked in. Carries the resolver's message.
class VaultUnavailable implements Exception {
  final String message;

  const VaultUnavailable(this.message);

  @override
  String toString() => message;
}

/// Riverpod retries a failed provider by default, which would leave the
/// repository stuck in `loading` (retrying) instead of surfacing
/// [VaultUnavailable]. An unusable vault is not a transient failure: the user
/// fixes it, and the fix re-resolves [openVaultProvider] anyway.
Duration? _neverRetry(int retryCount, Object error) => null;

/// A [PeriodRepository] over the open vault. Rebuilds when the vault
/// changes; errors with [VaultUnavailable] when the vault cannot be opened,
/// so nothing ever runs against a placeholder folder.
@Riverpod(retry: _neverRetry)
Future<PeriodRepository> periodRepository(Ref ref) async {
  final open = await ref.watch(openVaultProvider.future);
  final workspace = open.workspace;
  if (workspace == null) {
    throw VaultUnavailable(open.accessError ?? 'The vault could not be opened.');
  }
  return PeriodRepository(workspace: workspace);
}
