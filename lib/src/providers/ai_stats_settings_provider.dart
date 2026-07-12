import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/ai_stats_settings_service.dart';

part 'ai_stats_settings_provider.g.dart';

/// Exposes and manages the "generate current-period stats file" toggle.
@riverpod
class AiStatsSettings extends _$AiStatsSettings {
  final _service = AiStatsSettingsService();

  @override
  FutureOr<bool> build() => _service.isEnabled();

  Future<void> setEnabled(bool enabled) async {
    await _service.setEnabled(enabled);
    state = AsyncData(enabled);
  }
}
