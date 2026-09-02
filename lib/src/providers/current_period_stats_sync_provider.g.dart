// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_period_stats_sync_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Keeps `current_stats.md` in the periods directory in sync with the
/// current period's data.
///
/// Purely reactive: every mutation path already funnels into
/// [currentPeriodProvider] / [periodStatsProvider] invalidation, so watching
/// them regenerates the file on any change — no explicit hook needed in the
/// mutation notifiers. Must be kept alive by a `ref.watch` at the app root.
///
/// Write/delete failures are swallowed: a stats-file problem must never
/// interrupt normal period editing.

@ProviderFor(currentPeriodStatsSync)
final currentPeriodStatsSyncProvider = CurrentPeriodStatsSyncProvider._();

/// Keeps `current_stats.md` in the periods directory in sync with the
/// current period's data.
///
/// Purely reactive: every mutation path already funnels into
/// [currentPeriodProvider] / [periodStatsProvider] invalidation, so watching
/// them regenerates the file on any change — no explicit hook needed in the
/// mutation notifiers. Must be kept alive by a `ref.watch` at the app root.
///
/// Write/delete failures are swallowed: a stats-file problem must never
/// interrupt normal period editing.

final class CurrentPeriodStatsSyncProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Keeps `current_stats.md` in the periods directory in sync with the
  /// current period's data.
  ///
  /// Purely reactive: every mutation path already funnels into
  /// [currentPeriodProvider] / [periodStatsProvider] invalidation, so watching
  /// them regenerates the file on any change — no explicit hook needed in the
  /// mutation notifiers. Must be kept alive by a `ref.watch` at the app root.
  ///
  /// Write/delete failures are swallowed: a stats-file problem must never
  /// interrupt normal period editing.
  CurrentPeriodStatsSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentPeriodStatsSyncProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentPeriodStatsSyncHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return currentPeriodStatsSync(ref);
  }
}

String _$currentPeriodStatsSyncHash() =>
    r'5d690c735ec2b23a6a7ed661f3c3c41a76337232';
