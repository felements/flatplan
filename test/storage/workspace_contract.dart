import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

/// Behaviour every [VaultWorkspace] implementation must share.
void runWorkspaceContract(
  String label,
  Future<VaultWorkspace> Function() create,
) {
  group('$label contract', () {
    late VaultWorkspace ws;

    setUp(() async {
      ws = await create();
    });

    test('lists nothing when empty', () async {
      expect(await ws.listFiles(), isEmpty);
    });

    test('write then read round-trips and lists the name', () async {
      await ws.writeString('a.yaml', 'x: 1');

      expect(await ws.readString('a.yaml'), 'x: 1');
      expect(await ws.listFiles(), ['a.yaml']);
      expect(await ws.exists('a.yaml'), isTrue);
    });

    test('listFiles is sorted by name', () async {
      await ws.writeString('b.yaml', '');
      await ws.writeString('a.yaml', '');

      expect(await ws.listFiles(), ['a.yaml', 'b.yaml']);
    });

    test('overwrite replaces content', () async {
      await ws.writeString('a.yaml', 'one');
      await ws.writeString('a.yaml', 'two');

      expect(await ws.readString('a.yaml'), 'two');
      expect(await ws.listFiles(), ['a.yaml']);
    });

    test('delete removes the file and is a no-op for a missing one', () async {
      await ws.writeString('a.yaml', 'x');
      await ws.delete('a.yaml');
      await ws.delete('a.yaml');

      expect(await ws.exists('a.yaml'), isFalse);
      expect(await ws.listFiles(), isEmpty);
    });

    test('exists is false for a missing file', () async {
      expect(await ws.exists('nope.yaml'), isFalse);
    });

    test('rejects names with separators or ..', () async {
      for (final bad in ['../x.yaml', 'sub/x.yaml', '', '..']) {
        expect(
          () => ws.writeString(bad, 'x'),
          throwsA(isA<ArgumentError>()),
          reason: 'writeString must reject "$bad"',
        );
        expect(
          () => ws.readString(bad),
          throwsA(isA<ArgumentError>()),
          reason: 'readString must reject "$bad"',
        );
      }
    });

    test('readString of a missing file throws', () async {
      expect(() => ws.readString('nope.yaml'), throwsA(anything));
    });
  });
}
