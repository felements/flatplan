import 'dart:async';

import 'sync_engine.dart';
import 'sync_status.dart';

/// Decides *when* the engine runs. Triggers are coarse and single-flight:
/// a trigger during a run queues exactly one re-run.
class SyncScheduler {
  final SyncEngine engine;
  final void Function(SyncStatus) onStatus;
  final Duration idleDelay;
  final Duration switchTimeout;

  Timer? _idleTimer;
  Future<void>? _running;
  bool _rerunQueued = false;
  bool _disposed = false;
  SyncStatus _status = const SyncStatus(state: SyncState.idle, dirtyCount: 0);

  SyncScheduler({
    required this.engine,
    required this.onStatus,
    this.idleDelay = const Duration(seconds: 15),
    this.switchTimeout = const Duration(seconds: 5),
  });

  SyncStatus get status => _status;

  /// A file was marked dirty. Restarts the idle timer.
  void noteChange(String name) {
    if (_disposed) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(idleDelay, () => _run(push: true));
    _emit(_status.state);
  }

  Future<void> pullNow() => _run(push: false);

  /// Pushes pending changes (pulling first), or just pulls when nothing
  /// is pending.
  Future<void> syncNow() => _run(push: engine.journal.dirty.isNotEmpty);

  Future<void> onAppPaused() {
    _idleTimer?.cancel();
    return _run(push: true);
  }

  /// Best effort before switching vaults: the switch proceeds regardless.
  Future<void> flushBeforeSwitch() async {
    _idleTimer?.cancel();
    try {
      await _flush().timeout(switchTimeout);
    } on TimeoutException {
      // The engine keeps running in the background; the journal has it all.
    }
  }

  Future<void> _flush() async {
    final running = _running;
    if (running != null) await running;
    await _run(push: true);
  }

  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
  }

  Future<void> _run({required bool push}) {
    final running = _running;
    if (running != null) {
      _rerunQueued = true;
      return running;
    }
    final future = _execute(push: push).whenComplete(() {
      _running = null;
      if (_rerunQueued && !_disposed) {
        _rerunQueued = false;
        unawaited(_run(push: engine.journal.dirty.isNotEmpty));
      }
    });
    _running = future;
    return future;
  }

  Future<void> _execute({required bool push}) async {
    if (_disposed) return;
    _emit(SyncState.syncing);
    final failure = push ? await engine.push() : await engine.pull();
    if (_disposed) return;
    if (failure == null) {
      _emit(SyncState.idle);
    } else {
      _emit(failure.isOffline ? SyncState.offline : SyncState.error);
    }
  }

  void _emit(SyncState state) {
    final journal = engine.journal;
    _status = SyncStatus(
      state: state,
      dirtyCount: journal.dirty.length,
      lastPullAt: journal.lastPullAt,
      lastPushAt: journal.lastPushAt,
      lastError: journal.lastError,
    );
    onStatus(_status);
  }
}
