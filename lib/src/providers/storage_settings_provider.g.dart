// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Exposes and manages the persisted data-directory, resolving sandbox access
/// (via security-scoped bookmarks on macOS) and falling back safely when the
/// configured folder is unreachable.

@ProviderFor(StorageSettings)
final storageSettingsProvider = StorageSettingsProvider._();

/// Exposes and manages the persisted data-directory, resolving sandbox access
/// (via security-scoped bookmarks on macOS) and falling back safely when the
/// configured folder is unreachable.
final class StorageSettingsProvider
    extends $AsyncNotifierProvider<StorageSettings, StorageDirectory> {
  /// Exposes and manages the persisted data-directory, resolving sandbox access
  /// (via security-scoped bookmarks on macOS) and falling back safely when the
  /// configured folder is unreachable.
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

String _$storageSettingsHash() => r'fd3999093bae425b4183867240b5b5a055b31eff';

/// Exposes and manages the persisted data-directory, resolving sandbox access
/// (via security-scoped bookmarks on macOS) and falling back safely when the
/// configured folder is unreachable.

abstract class _$StorageSettings extends $AsyncNotifier<StorageDirectory> {
  FutureOr<StorageDirectory> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<StorageDirectory>, StorageDirectory>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<StorageDirectory>, StorageDirectory>,
              AsyncValue<StorageDirectory>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
