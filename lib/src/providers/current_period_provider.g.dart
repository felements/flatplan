// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_period_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CurrentPeriod)
final currentPeriodProvider = CurrentPeriodProvider._();

final class CurrentPeriodProvider
    extends $AsyncNotifierProvider<CurrentPeriod, Period?> {
  CurrentPeriodProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentPeriodProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentPeriodHash();

  @$internal
  @override
  CurrentPeriod create() => CurrentPeriod();
}

String _$currentPeriodHash() => r'829acedc4e449779a5d6ef505911d1771802a7bd';

abstract class _$CurrentPeriod extends $AsyncNotifier<Period?> {
  FutureOr<Period?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Period?>, Period?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Period?>, Period?>,
              AsyncValue<Period?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
