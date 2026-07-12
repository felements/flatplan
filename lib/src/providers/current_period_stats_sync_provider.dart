import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../logic/period_extensions.dart';
import '../logic/period_stats_markdown.dart';
import '../storage/period_stats_writer.dart';
import 'ai_stats_settings_provider.dart';
import 'all_periods_provider.dart';
import 'current_period_provider.dart';
import 'period_stats_provider.dart';
import 'repository_provider.dart';

part 'current_period_stats_sync_provider.g.dart';

/// Keeps `current_stats.md` in the periods directory in sync with the
/// current period's data.
///
/// Purely reactive: every mutation path already funnels into
/// [currentPeriodProvider] / [periodStatsProvider] invalidation, so watching
/// them regenerates the file on any change — no explicit hook needed in the
/// mutation notifiers. Must be kept alive by a `ref.watch` at the app root.
///
/// Write/delete failures are swallowed: a stats-file problem must never
/// interrupt normal period editing.
@riverpod
Future<void> currentPeriodStatsSync(Ref ref) async {
  final repo = ref.watch(periodRepositoryProvider);
  final writer = PeriodStatsWriter(directoryPath: repo.directoryPath);

  final enabled = await ref.watch(aiStatsSettingsProvider.future);
  if (!enabled) {
    try {
      await writer.deleteStatsFile();
    } catch (_) {}
    return;
  }

  final period = await ref.watch(currentPeriodProvider.future);
  final stats = await ref.watch(periodStatsProvider.future);
  if (period == null || stats == null) return;

  final allPeriods = await ref.watch(allPeriodsProvider.future);
  final endDate = effectiveEndDate(period, allPeriods);

  final markdown = formatCurrentPeriodStatsMarkdown(
    period: period,
    stats: stats,
    endDate: endDate,
    now: DateTime.now(),
  );
  try {
    await writer.writeStatsFile(markdown);
  } catch (_) {}
}
