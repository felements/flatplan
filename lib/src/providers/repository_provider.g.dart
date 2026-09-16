// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A [PeriodRepository] over the open vault. Rebuilds when the vault
/// changes; errors with [VaultUnavailable] when the vault cannot be opened,
/// so nothing ever runs against a placeholder folder.

@ProviderFor(periodRepository)
final periodRepositoryProvider = PeriodRepositoryProvider._();

/// A [PeriodRepository] over the open vault. Rebuilds when the vault
/// changes; errors with [VaultUnavailable] when the vault cannot be opened,
/// so nothing ever runs against a placeholder folder.

final class PeriodRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<PeriodRepository>,
          PeriodRepository,
          FutureOr<PeriodRepository>
        >
    with $FutureModifier<PeriodRepository>, $FutureProvider<PeriodRepository> {
  /// A [PeriodRepository] over the open vault. Rebuilds when the vault
  /// changes; errors with [VaultUnavailable] when the vault cannot be opened,
  /// so nothing ever runs against a placeholder folder.
  PeriodRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: _neverRetry,
        name: r'periodRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$periodRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<PeriodRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PeriodRepository> create(Ref ref) {
    return periodRepository(ref);
  }
}

String _$periodRepositoryHash() => r'2dc5211b07b001fcd8af9a526e8cb50dc369570b';
