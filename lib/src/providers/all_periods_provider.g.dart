// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'all_periods_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reads every period file once, keeping both the periods that loaded and
/// the files that could not be read.

@ProviderFor(periodLoadResult)
final periodLoadResultProvider = PeriodLoadResultProvider._();

/// Reads every period file once, keeping both the periods that loaded and
/// the files that could not be read.

final class PeriodLoadResultProvider
    extends
        $FunctionalProvider<
          AsyncValue<PeriodLoadResult>,
          PeriodLoadResult,
          FutureOr<PeriodLoadResult>
        >
    with $FutureModifier<PeriodLoadResult>, $FutureProvider<PeriodLoadResult> {
  /// Reads every period file once, keeping both the periods that loaded and
  /// the files that could not be read.
  PeriodLoadResultProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'periodLoadResultProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$periodLoadResultHash();

  @$internal
  @override
  $FutureProviderElement<PeriodLoadResult> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PeriodLoadResult> create(Ref ref) {
    return periodLoadResult(ref);
  }
}

String _$periodLoadResultHash() => r'93fb3a4602762e1b42c8e7729ed7a91f37388d91';

/// Provides all stored periods sorted descending by start date.

@ProviderFor(allPeriods)
final allPeriodsProvider = AllPeriodsProvider._();

/// Provides all stored periods sorted descending by start date.

final class AllPeriodsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Period>>,
          List<Period>,
          FutureOr<List<Period>>
        >
    with $FutureModifier<List<Period>>, $FutureProvider<List<Period>> {
  /// Provides all stored periods sorted descending by start date.
  AllPeriodsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allPeriodsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allPeriodsHash();

  @$internal
  @override
  $FutureProviderElement<List<Period>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Period>> create(Ref ref) {
    return allPeriods(ref);
  }
}

String _$allPeriodsHash() => r'3c6b8a84ff1beba269d257ff3e91c7cef8a4eaf9';

/// Period files that could not be read, for surfacing in the UI.

@ProviderFor(periodLoadFailures)
final periodLoadFailuresProvider = PeriodLoadFailuresProvider._();

/// Period files that could not be read, for surfacing in the UI.

final class PeriodLoadFailuresProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PeriodLoadFailure>>,
          List<PeriodLoadFailure>,
          FutureOr<List<PeriodLoadFailure>>
        >
    with
        $FutureModifier<List<PeriodLoadFailure>>,
        $FutureProvider<List<PeriodLoadFailure>> {
  /// Period files that could not be read, for surfacing in the UI.
  PeriodLoadFailuresProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'periodLoadFailuresProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$periodLoadFailuresHash();

  @$internal
  @override
  $FutureProviderElement<List<PeriodLoadFailure>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PeriodLoadFailure>> create(Ref ref) {
    return periodLoadFailures(ref);
  }
}

String _$periodLoadFailuresHash() =>
    r'8e42e2262e7ec01cbea7d5a42f322dc069bdcd65';
