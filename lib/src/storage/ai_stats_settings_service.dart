import 'package:shared_preferences/shared_preferences.dart';

/// Persists the "generate current-period stats file" toggle.
///
/// Defaults to enabled so the AI-insights pipeline works out of the box;
/// the user can opt out in Settings.
class AiStatsSettingsService {
  static const _key = 'ai_stats_enabled';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}
