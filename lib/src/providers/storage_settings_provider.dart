import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/storage_settings_service.dart';

part 'storage_settings_provider.g.dart';

/// Exposes and manages the persisted data-directory, resolving sandbox access
/// (via security-scoped bookmarks on macOS) and falling back safely when the
/// configured folder is unreachable.
@riverpod
class StorageSettings extends _$StorageSettings {
  final _service = StorageSettingsService();

  @override
  FutureOr<StorageDirectory> build() => _service.resolveDataDirectory();

  /// Saves a new directory, re-establishes access, and updates state so the
  /// repository provider re-reads from the new location.
  Future<void> updateDirectory(String path) async {
    await _service.setDataDirectory(path);
    state = AsyncData(await _service.resolveDataDirectory());
  }

  /// Reverts to the default application data directory.
  Future<void> resetToDefault() async {
    await _service.resetToDefault();
    state = AsyncData(await _service.resolveDataDirectory());
  }
}
