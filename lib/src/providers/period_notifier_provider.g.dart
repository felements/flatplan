// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'period_notifier_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A family provider that loads and mutates any period by its [periodId].
///
/// Use this instead of [currentPeriodProvider] when operating on a
/// period that may not be the latest one (e.g. historical periods).

@ProviderFor(PeriodNotifier)
final periodProvider = PeriodNotifierFamily._();

/// A family provider that loads and mutates any period by its [periodId].
///
/// Use this instead of [currentPeriodProvider] when operating on a
/// period that may not be the latest one (e.g. historical periods).
final class PeriodNotifierProvider
    extends $AsyncNotifierProvider<PeriodNotifier, Period?> {
  /// A family provider that loads and mutates any period by its [periodId].
  ///
  /// Use this instead of [currentPeriodProvider] when operating on a
  /// period that may not be the latest one (e.g. historical periods).
  PeriodNotifierProvider._({
    required PeriodNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'periodProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$periodNotifierHash();

  @override
  String toString() {
    return r'periodProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PeriodNotifier create() => PeriodNotifier();

  @override
  bool operator ==(Object other) {
    return other is PeriodNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$periodNotifierHash() => r'8805f4647270c6171336963b80f617e787b42b08';

/// A family provider that loads and mutates any period by its [periodId].
///
/// Use this instead of [currentPeriodProvider] when operating on a
/// period that may not be the latest one (e.g. historical periods).

final class PeriodNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          PeriodNotifier,
          AsyncValue<Period?>,
          Period?,
          FutureOr<Period?>,
          String
        > {
  PeriodNotifierFamily._()
    : super(
        retry: null,
        name: r'periodProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A family provider that loads and mutates any period by its [periodId].
  ///
  /// Use this instead of [currentPeriodProvider] when operating on a
  /// period that may not be the latest one (e.g. historical periods).

  PeriodNotifierProvider call(String periodId) =>
      PeriodNotifierProvider._(argument: periodId, from: this);

  @override
  String toString() => r'periodProvider';
}

/// A family provider that loads and mutates any period by its [periodId].
///
/// Use this instead of [currentPeriodProvider] when operating on a
/// period that may not be the latest one (e.g. historical periods).

abstract class _$PeriodNotifier extends $AsyncNotifier<Period?> {
  late final _$args = ref.$arg as String;
  String get periodId => _$args;

  FutureOr<Period?> build(String periodId);
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
    element.handleCreate(ref, () => build(_$args));
  }
}
