import 'package:freezed_annotation/freezed_annotation.dart';

part 'vault.freezed.dart';
part 'vault.g.dart';

/// Converts a Map (which may have dynamic keys) to `Map<String, dynamic>`.
Map<String, dynamic> _settingsFromJson(Object? json) {
  if (json == null) return const {};
  if (json is Map<String, dynamic>) return json;
  if (json is Map) {
    return Map<String, dynamic>.from(json);
  }
  return const {};
}

/// A named place that holds one set of period files.
@freezed
sealed class Vault with _$Vault {
  const factory Vault({
    required String id,
    required String name,
    required VaultLocation location,
    required DateTime createdAt,
  }) = _Vault;

  factory Vault.fromJson(Map<String, dynamic> json) => _$VaultFromJson(json);
}

/// Where a vault's files live.
///
/// `local` is a folder the app reads directly: the default app-support
/// folder, a user-picked folder, or an app-private folder on mobile.
/// `remote` is a provider such as `gitlab` or `webdav`; the app works on a
/// local mirror and a sync engine talks to the provider. `settings` holds
/// non-secret provider configuration; secrets live in the keychain under the
/// names listed in `secretNames`. An unknown `kind` is preserved untouched.
@Freezed(unionKey: 'type')
sealed class VaultLocation with _$VaultLocation {
  const factory VaultLocation.local({
    required String path,
    String? bookmark,
  }) = LocalVaultLocation;

  const factory VaultLocation.remote({
    required String kind,
    @JsonKey(fromJson: _settingsFromJson) @Default({}) Map<String, dynamic> settings,
    @Default([]) List<String> secretNames,
  }) = RemoteVaultLocation;

  factory VaultLocation.fromJson(Map<String, dynamic> json) =>
      _$VaultLocationFromJson(json);
}
