// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Exposes and manages the persisted data-directory path.

@ProviderFor(StorageSettings)
final storageSettingsProvider = StorageSettingsProvider._();

/// Exposes and manages the persisted data-directory path.
final class StorageSettingsProvider
    extends $AsyncNotifierProvider<StorageSettings, String> {
  /// Exposes and manages the persisted data-directory path.
  StorageSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageSettingsHash();

  @$internal
  @override
  StorageSettings create() => StorageSettings();
}

String _$storageSettingsHash() => r'e1bb528b4865d4d35abef6d6526956177f9c81af';

/// Exposes and manages the persisted data-directory path.

abstract class _$StorageSettings extends $AsyncNotifier<String> {
  FutureOr<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String>, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String>, String>,
              AsyncValue<String>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
