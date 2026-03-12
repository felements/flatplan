import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/storage_settings_service.dart';

part 'storage_settings_provider.g.dart';

/// Exposes and manages the persisted data-directory path.
@riverpod
class StorageSettings extends _$StorageSettings {
  final _service = StorageSettingsService();

  @override
  FutureOr<String> build() => _service.getDataDirectory();

  /// Saves a new directory path, updates state, and forces the repository
  /// provider to re-read from the new location.
  Future<void> updateDirectory(String path) async {
    await _service.setDataDirectory(path);
    state = AsyncData(path);
  }
}
