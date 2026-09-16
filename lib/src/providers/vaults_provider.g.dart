// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vaults_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vaultRegistryService)
final vaultRegistryServiceProvider = VaultRegistryServiceProvider._();

final class VaultRegistryServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<VaultRegistryService>,
          VaultRegistryService,
          FutureOr<VaultRegistryService>
        >
    with
        $FutureModifier<VaultRegistryService>,
        $FutureProvider<VaultRegistryService> {
  VaultRegistryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultRegistryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultRegistryServiceHash();

  @$internal
  @override
  $FutureProviderElement<VaultRegistryService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VaultRegistryService> create(Ref ref) {
    return vaultRegistryService(ref);
  }
}

String _$vaultRegistryServiceHash() =>
    r'b812629d0e21fea359b3915e3b606db21f3185d1';

/// Secret storage for remote vaults. In-memory until the first remote
/// provider brings the keychain implementation.

@ProviderFor(vaultSecrets)
final vaultSecretsProvider = VaultSecretsProvider._();

/// Secret storage for remote vaults. In-memory until the first remote
/// provider brings the keychain implementation.

final class VaultSecretsProvider
    extends $FunctionalProvider<VaultSecrets, VaultSecrets, VaultSecrets>
    with $Provider<VaultSecrets> {
  /// Secret storage for remote vaults. In-memory until the first remote
  /// provider brings the keychain implementation.
  VaultSecretsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultSecretsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultSecretsHash();

  @$internal
  @override
  $ProviderElement<VaultSecrets> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VaultSecrets create(Ref ref) {
    return vaultSecrets(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VaultSecrets value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VaultSecrets>(value),
    );
  }
}

String _$vaultSecretsHash() => r'dfd6be2f498f33f6e20e254f9b833fbc0b8bfa1e';

/// The vault registry: every known vault and which one is selected.

@ProviderFor(Vaults)
final vaultsProvider = VaultsProvider._();

/// The vault registry: every known vault and which one is selected.
final class VaultsProvider
    extends $AsyncNotifierProvider<Vaults, VaultRegistry> {
  /// The vault registry: every known vault and which one is selected.
  VaultsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultsHash();

  @$internal
  @override
  Vaults create() => Vaults();
}

String _$vaultsHash() => r'814cd4d895f1760933a68c402db90723e43ab361';

/// The vault registry: every known vault and which one is selected.

abstract class _$Vaults extends $AsyncNotifier<VaultRegistry> {
  FutureOr<VaultRegistry> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<VaultRegistry>, VaultRegistry>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VaultRegistry>, VaultRegistry>,
              AsyncValue<VaultRegistry>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
