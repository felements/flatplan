import '../models/models.dart';

/// A file as the provider holds it, with the provider's version token.
class RemoteFile {
  final String content;

  /// Opaque: an etag, a blob SHA, a revision id. Only ever compared for
  /// equality.
  final String version;

  const RemoteFile({required this.content, required this.version});
}

/// One change in a push batch. [expectedVersion] is the version the change
/// was based on, so a store that can check it rejects stale writes.
sealed class RemoteChange {
  final String name;
  final String? expectedVersion;

  const RemoteChange({required this.name, required this.expectedVersion});
}

final class RemotePut extends RemoteChange {
  final String content;

  /// [expectedVersion] is null for a file the remote should not have yet.
  const RemotePut({
    required super.name,
    required this.content,
    required super.expectedVersion,
  });
}

final class RemoteDelete extends RemoteChange {
  const RemoteDelete({
    required super.name,
    required String expectedVersion,
  }) : super(expectedVersion: expectedVersion);
}

/// Thrown by [RemoteStore.writeBatch] when an expected version is stale.
/// The engine responds by pulling again and rebuilding the batch.
class RemoteConflict implements Exception {
  final List<String> names;

  const RemoteConflict(this.names);

  @override
  String toString() => 'RemoteConflict(${names.join(', ')})';
}

/// The whole surface a provider implements. Only the sync engine calls it.
abstract interface class RemoteStore {
  /// File name to version for every file in the vault's remote folder.
  Future<Map<String, String>> listTree();

  Future<RemoteFile> read(String name);

  /// Applies every change, atomically where the provider allows it (git
  /// providers make one commit). Returns the new version of each put;
  /// deleted names are absent. Throws [RemoteConflict] when it can detect a
  /// stale [RemoteChange.expectedVersion].
  Future<Map<String, String>> writeBatch(List<RemoteChange> changes);
}

/// Builds a store for a remote vault from its non-secret settings and the
/// secrets read from the keychain, keyed by name.
typedef RemoteStoreFactory =
    Future<RemoteStore> Function(
      RemoteVaultLocation location,
      Map<String, String> secrets,
    );

/// Which remote kinds this build can open. Each provider registers itself
/// here; an unregistered kind is "not supported in this version".
class RemoteStoreRegistry {
  final Map<String, RemoteStoreFactory> _factories = {};

  void register(String kind, RemoteStoreFactory factory) {
    _factories[kind] = factory;
  }

  RemoteStoreFactory? factoryFor(String kind) => _factories[kind];

  bool supports(String kind) => _factories.containsKey(kind);
}
