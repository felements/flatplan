import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/period_repository.dart';
import '../storage/vault_workspace.dart';
import 'storage_settings_provider.dart';

part 'repository_provider.g.dart';

/// Provides a [PeriodRepository] wired to the user-selected data directory.
///
/// Re-creates automatically whenever [storageSettingsProvider] changes.
@riverpod
PeriodRepository periodRepository(Ref ref) {
  final dirAsync = ref.watch(storageSettingsProvider);
  final path = dirAsync.value?.path ?? _fallbackPath();
  return PeriodRepository(workspace: DirectoryWorkspace(path));
}

/// Temporary fallback while [storageSettingsProvider] resolves.
String _fallbackPath() {
  return '${Directory.systemTemp.path}/flatplan_fallback';
}
