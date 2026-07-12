import 'package:flatplan/src/storage/ai_stats_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to enabled when nothing is stored', () async {
    expect(await AiStatsSettingsService().isEnabled(), isTrue);
  });

  test('persists a disabled state across reads', () async {
    final service = AiStatsSettingsService();
    await service.setEnabled(false);
    expect(await AiStatsSettingsService().isEnabled(), isFalse);
  });

  test('re-enabling persists too', () async {
    final service = AiStatsSettingsService();
    await service.setEnabled(false);
    await service.setEnabled(true);
    expect(await service.isEnabled(), isTrue);
  });
}
