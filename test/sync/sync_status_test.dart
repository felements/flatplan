import 'package:flatplan/src/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 16, 12, 0);

  SyncStatus idle({int dirty = 0, DateTime? pushed, DateTime? pulled}) =>
      SyncStatus(
        state: SyncState.idle,
        dirtyCount: dirty,
        lastPushAt: pushed,
        lastPullAt: pulled,
      );

  test('describe covers every state', () {
    expect(
      const SyncStatus(state: SyncState.syncing, dirtyCount: 0).describe(now),
      'Syncing…',
    );
    expect(
      const SyncStatus(state: SyncState.offline, dirtyCount: 2).describe(now),
      'Offline · 2 changes pending',
    );
    expect(
      const SyncStatus(state: SyncState.offline, dirtyCount: 0).describe(now),
      'Offline',
    );
    expect(
      const SyncStatus(state: SyncState.error, dirtyCount: 0, lastError: 'GitLab rejected the token.')
          .describe(now),
      'Sync failed: GitLab rejected the token.',
    );
    expect(
      const SyncStatus(state: SyncState.error, dirtyCount: 0).describe(now),
      'Sync failed',
    );
    expect(idle(dirty: 1).describe(now), '1 change pending');
    expect(idle(dirty: 3).describe(now), '3 changes pending');
    expect(idle().describe(now), 'Not synced yet');
  });

  test('describe formats how long ago the last sync was', () {
    expect(idle(pushed: now.subtract(const Duration(seconds: 20))).describe(now),
        'Synced just now');
    expect(idle(pushed: now.subtract(const Duration(minutes: 2))).describe(now),
        'Synced 2 min ago');
    expect(idle(pulled: now.subtract(const Duration(hours: 3))).describe(now),
        'Synced 3 h ago');
    expect(idle(pushed: now.subtract(const Duration(days: 2))).describe(now),
        'Synced 2 d ago');
  });

  test('the most recent of pull and push counts', () {
    final status = idle(
      pulled: now.subtract(const Duration(minutes: 1)),
      pushed: now.subtract(const Duration(hours: 1)),
    );
    expect(status.describe(now), 'Synced 1 min ago');
  });
}
