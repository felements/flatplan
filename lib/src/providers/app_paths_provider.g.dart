// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_paths_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app-support locations, resolved once per app run.

@ProviderFor(appPaths)
final appPathsProvider = AppPathsProvider._();

/// The app-support locations, resolved once per app run.

final class AppPathsProvider
    extends
        $FunctionalProvider<AsyncValue<AppPaths>, AppPaths, FutureOr<AppPaths>>
    with $FutureModifier<AppPaths>, $FutureProvider<AppPaths> {
  /// The app-support locations, resolved once per app run.
  AppPathsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appPathsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appPathsHash();

  @$internal
  @override
  $FutureProviderElement<AppPaths> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AppPaths> create(Ref ref) {
    return appPaths(ref);
  }
}

String _$appPathsHash() => r'6dd8a87e28c9861a2371e4f0e36c3b67fed3f064';
