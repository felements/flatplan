import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's chosen data directory path via SharedPreferences.
class StorageSettingsService {
  static const _key = 'data_directory';

  /// Returns the saved data directory, or the default (executable's sibling
  /// folder) if none has been set.
  Future<String> getDataDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) return saved;
    return defaultDirectory();
  }

  /// Persists a new data directory path.
  Future<void> setDataDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }

  /// Default: `<executable_dir>/flatplan_data/periods`.
  static String defaultDirectory() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir/flatplan_data/periods';
  }
}
