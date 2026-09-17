// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gitlab_connect_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How the connect flow builds an API client. Tests override this with a
/// factory over a `MockClient`.

@ProviderFor(gitLabApiFactory)
final gitLabApiFactoryProvider = GitLabApiFactoryProvider._();

/// How the connect flow builds an API client. Tests override this with a
/// factory over a `MockClient`.

final class GitLabApiFactoryProvider
    extends
        $FunctionalProvider<
          GitLabApiFactory,
          GitLabApiFactory,
          GitLabApiFactory
        >
    with $Provider<GitLabApiFactory> {
  /// How the connect flow builds an API client. Tests override this with a
  /// factory over a `MockClient`.
  GitLabApiFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gitLabApiFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gitLabApiFactoryHash();

  @$internal
  @override
  $ProviderElement<GitLabApiFactory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GitLabApiFactory create(Ref ref) {
    return gitLabApiFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GitLabApiFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GitLabApiFactory>(value),
    );
  }
}

String _$gitLabApiFactoryHash() => r'24963a2185290aae2183ebc5604eaab9df6f419e';
