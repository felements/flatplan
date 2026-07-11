// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides a [PeriodRepository] wired to the user-selected data directory.
///
/// Re-creates automatically whenever [storageSettingsProvider] changes.

@ProviderFor(periodRepository)
final periodRepositoryProvider = PeriodRepositoryProvider._();

/// Provides a [PeriodRepository] wired to the user-selected data directory.
///
/// Re-creates automatically whenever [storageSettingsProvider] changes.

final class PeriodRepositoryProvider
    extends
        $FunctionalProvider<
          PeriodRepository,
          PeriodRepository,
          PeriodRepository
        >
    with $Provider<PeriodRepository> {
  /// Provides a [PeriodRepository] wired to the user-selected data directory.
  ///
  /// Re-creates automatically whenever [storageSettingsProvider] changes.
  PeriodRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'periodRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$periodRepositoryHash();

  @$internal
  @override
  $ProviderElement<PeriodRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PeriodRepository create(Ref ref) {
    return periodRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PeriodRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PeriodRepository>(value),
    );
  }
}

String _$periodRepositoryHash() => r'af5f932bfdeb0d39820af65f715d2ea2c6df4f86';
