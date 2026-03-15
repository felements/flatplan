import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's chosen data directory path via SharedPreferences.
class StorageSettingsService {
  static const _key = 'data_directory';

  /// Returns the saved data directory, or the default (system app-support
  /// folder) if none has been set.
  Future<String> getDataDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) return saved;
    return await defaultDirectory();
  }

  /// Persists a new data directory path.
  Future<void> setDataDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }

  /// Default: `<app_support>/flatplan/periods`.
  ///
  /// Uses `getApplicationSupportDirectory()` which resolves to a writable
  /// location on all platforms, including MSIX-packaged Windows apps.
  static Future<String> defaultDirectory() async {
    final appSupport = await getApplicationSupportDirectory();
    return p.join(appSupport.path, 'periods');
  }
}
