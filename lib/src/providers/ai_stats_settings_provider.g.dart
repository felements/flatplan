// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_stats_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Exposes and manages the "generate current-period stats file" toggle.

@ProviderFor(AiStatsSettings)
final aiStatsSettingsProvider = AiStatsSettingsProvider._();

/// Exposes and manages the "generate current-period stats file" toggle.
final class AiStatsSettingsProvider
    extends $AsyncNotifierProvider<AiStatsSettings, bool> {
  /// Exposes and manages the "generate current-period stats file" toggle.
  AiStatsSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiStatsSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiStatsSettingsHash();

  @$internal
  @override
  AiStatsSettings create() => AiStatsSettings();
}

String _$aiStatsSettingsHash() => r'3e6628da1010daf2822c718391c5df073ac6ab9a';

/// Exposes and manages the "generate current-period stats file" toggle.

abstract class _$AiStatsSettings extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
