import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/period_repository.dart';
import 'storage_settings_provider.dart';

part 'repository_provider.g.dart';

/// Provides a [PeriodRepository] wired to the user-selected data directory.
///
/// Re-creates automatically whenever [storageSettingsProvider] changes.
@riverpod
PeriodRepository periodRepository(Ref ref) {
  final dirAsync = ref.watch(storageSettingsProvider);
  final path = dirAsync.value ?? _fallbackPath();
  return PeriodRepository(directoryPath: path);
}

/// Inline fallback so the provider never blocks on a null.
String _fallbackPath() {
  // Same logic as StorageSettingsService._defaultDirectory
  return '.';
}
