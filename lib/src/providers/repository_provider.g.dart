// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(periodRepository)
final periodRepositoryProvider = PeriodRepositoryProvider._();

final class PeriodRepositoryProvider
    extends
        $FunctionalProvider<
          PeriodRepository,
          PeriodRepository,
          PeriodRepository
        >
    with $Provider<PeriodRepository> {
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

String _$periodRepositoryHash() => r'9076b2deda30fb08f92a560eb99d72a40e0a84a8';
