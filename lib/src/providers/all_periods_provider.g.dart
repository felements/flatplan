// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'all_periods_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

String _$allPeriodsHash() => r'e1d56541864c39c0a53f3a884bc7b84328bce0d0';
