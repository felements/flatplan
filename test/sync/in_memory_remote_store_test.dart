import 'dart:io';

import 'package:flatplan/src/sync/remote_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_remote_store.dart';

void main() {
  late InMemoryRemoteStore store;

  setUp(() => store = InMemoryRemoteStore());

  test('seed assigns versions and listTree reports them', () async {
    store.seed('a.yaml', 'x');
    store.seed('b.yaml', 'y');

    final tree = await store.listTree();

    expect(tree.keys, ['a.yaml', 'b.yaml']);
    expect(tree['a.yaml'], isNot(tree['b.yaml']));
    expect((await store.read('a.yaml')).content, 'x');
  });

  test('writeBatch applies puts and deletes and returns put versions',
      () async {
    store.seed('old.yaml', 'x');
    final oldVersion = (await store.listTree())['old.yaml']!;

    final versions = await store.writeBatch([
      RemotePut(name: 'new.yaml', content: 'n', expectedVersion: null),
      RemoteDelete(name: 'old.yaml', expectedVersion: oldVersion),
    ]);

    expect(versions.keys, ['new.yaml']);
    expect(await store.listTree(), {'new.yaml': versions['new.yaml']});
  });

  test('writeBatch rejects the whole batch on a stale expected version',
      () async {
    store.seed('a.yaml', 'x');

    await expectLater(
      store.writeBatch([
        RemotePut(name: 'a.yaml', content: 'y', expectedVersion: 'stale'),
        RemotePut(name: 'b.yaml', content: 'z', expectedVersion: null),
      ]),
      throwsA(isA<RemoteConflict>().having((c) => c.names, 'names', ['a.yaml'])),
    );
    expect(await store.listTree(), hasLength(1));
  });

  test('a put with a null expected version conflicts when the file exists',
      () async {
    store.seed('a.yaml', 'x');

    expect(
      () => store.writeBatch([
        RemotePut(name: 'a.yaml', content: 'y', expectedVersion: null),
      ]),
      throwsA(isA<RemoteConflict>()),
    );
  });

  test('failAfterWrites applies part of the batch then throws', () async {
    store.failAfterWrites = 1;

    await expectLater(
      store.writeBatch([
        RemotePut(name: 'a.yaml', content: '1', expectedVersion: null),
        RemotePut(name: 'b.yaml', content: '2', expectedVersion: null),
      ]),
      throwsA(isA<SocketException>()),
    );

    expect((await store.listTree()).keys, ['a.yaml']);
  });

  test('failure makes every call throw', () async {
    store.failure = const SocketException('offline');

    expect(store.listTree, throwsA(isA<SocketException>()));
  });

  test('RemoteStoreRegistry looks factories up by kind', () async {
    final registry = RemoteStoreRegistry();
    expect(registry.supports('memory'), isFalse);

    registry.register('memory', (location, secrets) async => store);

    expect(registry.supports('memory'), isTrue);
    expect(registry.factoryFor('memory'), isNotNull);
    expect(registry.factoryFor('nope'), isNull);
  });
}
