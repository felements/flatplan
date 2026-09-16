import 'dart:async';

import 'package:flatplan/src/sync/lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('actions run one at a time in call order', () async {
    final lock = Lock();
    final log = <String>[];
    final gate = Completer<void>();

    final first = lock.synchronized(() async {
      log.add('first start');
      await gate.future;
      log.add('first end');
    });
    final second = lock.synchronized(() async {
      log.add('second');
    });
    await Future<void>.delayed(Duration.zero);
    expect(log, ['first start']);

    gate.complete();
    await Future.wait([first, second]);
    expect(log, ['first start', 'first end', 'second']);
  });

  test('a failing action releases the lock and rethrows', () async {
    final lock = Lock();
    await expectLater(
      lock.synchronized(() async => throw StateError('boom')),
      throwsStateError,
    );
    expect(await lock.synchronized(() async => 42), 42);
  });

  test('returns the action result', () async {
    expect(await Lock().synchronized(() async => 'x'), 'x');
  });
}
