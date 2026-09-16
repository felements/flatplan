enum SyncState { idle, syncing, offline, error }

/// What the switcher and Settings show for the open remote vault.
class SyncStatus {
  final SyncState state;
  final int dirtyCount;
  final DateTime? lastPullAt;
  final DateTime? lastPushAt;
  final String? lastError;

  const SyncStatus({
    required this.state,
    required this.dirtyCount,
    this.lastPullAt,
    this.lastPushAt,
    this.lastError,
  });

  /// One short line for the UI.
  String describe(DateTime now) {
    final pending = dirtyCount == 1 ? '1 change pending' : '$dirtyCount changes pending';
    switch (state) {
      case SyncState.syncing:
        return 'Syncing…';
      case SyncState.offline:
        return dirtyCount > 0 ? 'Offline · $pending' : 'Offline';
      case SyncState.error:
        return 'Sync failed';
      case SyncState.idle:
        if (dirtyCount > 0) return pending;
        final last = _latest(lastPullAt, lastPushAt);
        if (last == null) return 'Not synced yet';
        return 'Synced ${_ago(now.difference(last))}';
    }
  }

  static DateTime? _latest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  static String _ago(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}
