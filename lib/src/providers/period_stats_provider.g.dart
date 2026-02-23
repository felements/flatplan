// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'period_stats_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(periodStats)
final periodStatsProvider = PeriodStatsProvider._();

final class PeriodStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PeriodStats?>,
          PeriodStats?,
          FutureOr<PeriodStats?>
        >
    with $FutureModifier<PeriodStats?>, $FutureProvider<PeriodStats?> {
  PeriodStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'periodStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$periodStatsHash();

  @$internal
  @override
  $FutureProviderElement<PeriodStats?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PeriodStats?> create(Ref ref) {
    return periodStats(ref);
  }
}

String _$periodStatsHash() => r'842c34683c018d77da8e97c76657c7c9642a078a';
