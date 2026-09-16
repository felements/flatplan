import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import '../sync/conflict_policy.dart';
import '../sync/remote_store.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_journal.dart';
import '../sync/sync_scheduler.dart';
import '../sync/sync_status.dart';
import 'app_paths.dart';
import 'security_scoped_bookmarks.dart';
import 'vault_secrets.dart';
import 'vault_workspace.dart';

/// A vault the app can work in, or the reason it cannot.
class OpenVault {
  final Vault vault;

  /// Null when [accessError] is set.
  final VaultWorkspace? workspace;

  /// Present for remote vaults only.
  final SyncScheduler? scheduler;

  /// Why the vault could not be opened. The vault stays selected; the UI
  /// explains and points at the vault's settings.
  final String? accessError;

  const OpenVault({
    required this.vault,
    this.workspace,
    this.scheduler,
    this.accessError,
  });

  bool get isUsable => workspace != null;

  bool get isRemote => vault.location is RemoteVaultLocation;

  void dispose() => scheduler?.dispose();
}

/// Turns a [Vault] into an [OpenVault]. Every platform quirk lives here:
/// macOS bookmarks, folders that may not exist yet, provider lookup.
class VaultResolver {
  static const unsupportedKindError =
      'This vault type is not supported in this version.';
  static const missingSecretError =
      'Sign in to this vault again in its settings.';
  static String missingFolderError(String path) =>
      'The folder "$path" could not be found. '
      'Choose it again in the vault settings.';

  final AppPaths paths;
  final RemoteStoreRegistry remoteStores;
  final VaultSecrets secrets;
  final ConflictPolicy policy;
  final Duration idleDelay;
  final Duration switchTimeout;

  /// Null on platforms without sandbox bookmarks.
  final SecurityScopedBookmarks? _bookmarks;

  VaultResolver({
    required this.paths,
    required this.remoteStores,
    required this.secrets,
    SecurityScopedBookmarks? bookmarks,
    bool? useBookmarks,
    ConflictPolicy? policy,
    this.idleDelay = const Duration(seconds: 15),
    this.switchTimeout = const Duration(seconds: 5),
  }) : _bookmarks = (useBookmarks ?? Platform.isMacOS)
           ? (bookmarks ?? MacosSecurityScopedBookmarks())
           : null,
       policy = policy ?? periodConflictPolicy;

  /// A bookmark for a just-picked folder, or null where bookmarks are not
  /// needed. Called by the local-folder form when the user picks a folder.
  Future<String?> bookmarkFor(String path) =>
      _bookmarks?.bookmarkForPath(path) ?? Future.value(null);

  Future<OpenVault> open(
    Vault vault, {
    void Function(SyncStatus)? onStatus,
  }) {
    switch (vault.location) {
      case LocalVaultLocation(:final path, :final bookmark):
        return _openLocal(vault, path, bookmark);
      case final RemoteVaultLocation location:
        return _openRemote(vault, location, onStatus);
    }
  }

  Future<OpenVault> _openLocal(
    Vault vault,
    String path,
    String? bookmark,
  ) async {
    var resolvedPath = path;
    final bookmarks = _bookmarks;
    if (bookmarks != null && bookmark != null) {
      try {
        resolvedPath = await bookmarks.resolvePath(bookmark);
        final granted = await bookmarks.startAccessing(resolvedPath);
        if (!granted) {
          throw const FileSystemException('Access to the folder was denied');
        }
      } catch (e) {
        return OpenVault(
          vault: vault,
          accessError:
              'FlatPlan could not open "$path" ($e). '
              'Choose the folder again in the vault settings.',
        );
      }
    }

    // Folders inside the app's own area are created on first write. A
    // user-picked folder that is gone is a problem the user must fix.
    final insideApp = p.isWithin(paths.appSupportDir, resolvedPath);
    if (!insideApp && !await Directory(resolvedPath).exists()) {
      return OpenVault(vault: vault, accessError: missingFolderError(path));
    }
    return OpenVault(vault: vault, workspace: DirectoryWorkspace(resolvedPath));
  }

  Future<OpenVault> _openRemote(
    Vault vault,
    RemoteVaultLocation location,
    void Function(SyncStatus)? onStatus,
  ) async {
    final factory = remoteStores.factoryFor(location.kind);
    if (factory == null) {
      return OpenVault(vault: vault, accessError: unsupportedKindError);
    }

    final secretValues = <String, String>{};
    for (final name in location.secretNames) {
      final value = await secrets.read(vault.id, name);
      if (value == null) {
        return OpenVault(vault: vault, accessError: missingSecretError);
      }
      secretValues[name] = value;
    }

    final RemoteStore store;
    try {
      store = await factory(location, secretValues);
    } catch (e) {
      // A provider that cannot build its store (bad settings, rejected
      // credentials) is an access error, not a crash in the app.
      return OpenVault(
        vault: vault,
        accessError: 'This vault could not be opened: $e',
      );
    }
    final journal = await SyncJournal.load(paths.journalFor(vault.id));
    final mirrorPath = paths.mirrorFor(vault.id);
    final engine = SyncEngine(
      mirror: DirectoryWorkspace(mirrorPath),
      remote: store,
      journal: journal,
      policy: policy,
    );
    final scheduler = SyncScheduler(
      engine: engine,
      onStatus: onStatus ?? (_) {},
      idleDelay: idleDelay,
      switchTimeout: switchTimeout,
    );
    journal.onDirty = scheduler.noteChange;

    return OpenVault(
      vault: vault,
      workspace: DirectoryWorkspace(mirrorPath, changeListener: journal),
      scheduler: scheduler,
    );
  }
}
