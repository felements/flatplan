import 'dart:async';

/// A future-chained mutex. Actions run one at a time in call order. Not
/// reentrant: an action must not call [synchronized] on the same lock.
class Lock {
  Future<void> _tail = Future.value();

  Future<T> synchronized<T>(Future<T> Function() action) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous.then((_) => action()).whenComplete(done.complete);
  }
}
