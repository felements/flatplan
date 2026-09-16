import 'dart:convert';
import 'dart:io';

import 'package:flatplan/src/sync/sync_journal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late String journalPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flatplan_journal_');
    journalPath = p.join(tempDir.path, 'v1', 'sync.json');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('contentHash is stable and differs by content', () {
    expect(contentHash('a'), contentHash('a'));
    expect(contentHash('a'), isNot(contentHash('b')));
    expect(contentHash('a'), hasLength(64));
  });

  test('load of a missing file gives an empty journal', () async {
    final journal = await SyncJournal.load(journalPath);

    expect(journal.baseline, isEmpty);
    expect(journal.dirty, isEmpty);
    expect(journal.needsFullRescan, isFalse);
  });

  test('onChanged marks dirty, persists, then notifies', () async {
    final journal = await SyncJournal.load(journalPath);
    final notified = <String>[];
    journal.onDirty = notified.add;

    await journal.onChanged('a.yaml');

    expect(journal.dirty, {'a.yaml'});
    expect(notified, ['a.yaml']);
    final onDisk = jsonDecode(File(journalPath).readAsStringSync());
    expect(onDisk['dirty'], ['a.yaml']);
  });

  test('save round-trips every field in snake_case', () async {
    final journal = await SyncJournal.load(journalPath);
    journal.baseline['a.yaml'] =
        const JournalEntry(version: 'v1', contentHash: 'h1');
    journal.dirty.add('b.yaml');
    journal.lastPullAt = DateTime.utc(2026, 9, 16, 10);
    journal.lastPushAt = DateTime.utc(2026, 9, 16, 11);
    journal.lastError = 'boom';
    await journal.save();

    final reloaded = await SyncJournal.load(journalPath);

    expect(reloaded.baseline, {
      'a.yaml': const JournalEntry(version: 'v1', contentHash: 'h1'),
    });
    expect(reloaded.dirty, {'b.yaml'});
    expect(reloaded.lastPullAt, DateTime.utc(2026, 9, 16, 10));
    expect(reloaded.lastPushAt, DateTime.utc(2026, 9, 16, 11));
    expect(reloaded.lastError, 'boom');
    final raw = jsonDecode(File(journalPath).readAsStringSync());
    expect(raw['baseline']['a.yaml']['content_hash'], 'h1');
    expect(raw['last_pull_at'], isA<String>());
    expect(File('$journalPath.tmp').existsSync(), isFalse);
  });

  test('a corrupt journal starts empty and asks for a full rescan', () async {
    File(journalPath).createSync(recursive: true);
    File(journalPath).writeAsStringSync('{ nope');

    final journal = await SyncJournal.load(journalPath);

    expect(journal.needsFullRescan, isTrue);
    expect(journal.dirty, isEmpty);
  });

  test('a parseable journal with a malformed entry also starts empty', () async {
    File(journalPath).createSync(recursive: true);
    File(journalPath).writeAsStringSync(
      '{"version":1,"baseline":{"a.yaml":{"version":"v1","content_hash":"h1"},'
      '"b.yaml":{"content_hash":"h2"}},"dirty":["c.yaml"]}',
    );

    final journal = await SyncJournal.load(journalPath);

    expect(journal.needsFullRescan, isTrue);
    expect(journal.baseline, isEmpty);
    expect(journal.dirty, isEmpty);
  });

  test('an in-memory journal saves nothing', () async {
    final journal = SyncJournal();
    await journal.onChanged('a.yaml');
    expect(journal.dirty, {'a.yaml'});
  });
}
