// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_vault_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Remote kinds this build can open. Empty until a provider registers.

@ProviderFor(remoteStoreRegistry)
final remoteStoreRegistryProvider = RemoteStoreRegistryProvider._();

/// Remote kinds this build can open. Empty until a provider registers.

final class RemoteStoreRegistryProvider
    extends
        $FunctionalProvider<
          RemoteStoreRegistry,
          RemoteStoreRegistry,
          RemoteStoreRegistry
        >
    with $Provider<RemoteStoreRegistry> {
  /// Remote kinds this build can open. Empty until a provider registers.
  RemoteStoreRegistryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteStoreRegistryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteStoreRegistryHash();

  @$internal
  @override
  $ProviderElement<RemoteStoreRegistry> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RemoteStoreRegistry create(Ref ref) {
    return remoteStoreRegistry(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemoteStoreRegistry value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemoteStoreRegistry>(value),
    );
  }
}

String _$remoteStoreRegistryHash() =>
    r'd3b1943baf1b327f63feda233e080976f1717a32';

@ProviderFor(vaultResolver)
final vaultResolverProvider = VaultResolverProvider._();

final class VaultResolverProvider
    extends
        $FunctionalProvider<
          AsyncValue<VaultResolver>,
          VaultResolver,
          FutureOr<VaultResolver>
        >
    with $FutureModifier<VaultResolver>, $FutureProvider<VaultResolver> {
  VaultResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultResolverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultResolverHash();

  @$internal
  @override
  $FutureProviderElement<VaultResolver> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VaultResolver> create(Ref ref) {
    return vaultResolver(ref);
  }
}

String _$vaultResolverHash() => r'951e31c98c0b5fae328b0b3843b517c71462f340';

/// Sync status of the open vault. Null for local vaults.

@ProviderFor(CurrentSyncStatus)
final currentSyncStatusProvider = CurrentSyncStatusProvider._();

/// Sync status of the open vault. Null for local vaults.
final class CurrentSyncStatusProvider
    extends $NotifierProvider<CurrentSyncStatus, SyncStatus?> {
  /// Sync status of the open vault. Null for local vaults.
  CurrentSyncStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSyncStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentSyncStatusHash();

  @$internal
  @override
  CurrentSyncStatus create() => CurrentSyncStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncStatus? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncStatus?>(value),
    );
  }
}

String _$currentSyncStatusHash() => r'76667fcdcfab02e91fd64920e25f3a19cc821509';

/// Sync status of the open vault. Null for local vaults.

abstract class _$CurrentSyncStatus extends $Notifier<SyncStatus?> {
  SyncStatus? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SyncStatus?, SyncStatus?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncStatus?, SyncStatus?>,
              SyncStatus?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The selected vault, resolved. Re-resolves when the selection changes;
/// the outgoing remote vault gets a best-effort push first.

@ProviderFor(openVault)
final openVaultProvider = OpenVaultProvider._();

/// The selected vault, resolved. Re-resolves when the selection changes;
/// the outgoing remote vault gets a best-effort push first.

final class OpenVaultProvider
    extends
        $FunctionalProvider<
          AsyncValue<OpenVault>,
          OpenVault,
          FutureOr<OpenVault>
        >
    with $FutureModifier<OpenVault>, $FutureProvider<OpenVault> {
  /// The selected vault, resolved. Re-resolves when the selection changes;
  /// the outgoing remote vault gets a best-effort push first.
  OpenVaultProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openVaultProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openVaultHash();

  @$internal
  @override
  $FutureProviderElement<OpenVault> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<OpenVault> create(Ref ref) {
    return openVault(ref);
  }
}

String _$openVaultHash() => r'b94d648ea4ea889264cc62d5068b572fd43e0289';
