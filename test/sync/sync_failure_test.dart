import 'dart:io';

import 'package:flatplan/src/sync/remote_store.dart';
import 'package:flatplan/src/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RemoteUnreachable is offline and keeps its message', () {
    final failure = SyncFailure.from(const RemoteUnreachable('Could not reach host'));
    expect(failure.isOffline, isTrue);
    expect(failure.message, 'Could not reach host');
  });

  test('RemoteAuthRejected is an error with a user-facing message', () {
    final failure = SyncFailure.from(const RemoteAuthRejected());
    expect(failure.isOffline, isFalse);
    expect(failure.message, contains('Replace it in the vault settings'));
  });

  test('an auth rejection needs the user\'s attention; connectivity does not', () {
    expect(SyncFailure.from(const RemoteAuthRejected()).needsAttention, isTrue);
    expect(SyncFailure.from(const RemoteUnreachable('x')).needsAttention, isFalse);
    expect(SyncFailure.from(StateError('x')).needsAttention, isFalse);
  });

  test('socket errors stay offline', () {
    expect(SyncFailure.from(const SocketException('x')).isOffline, isTrue);
  });
}
