import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../storage/vault_workspace.dart';

/// SHA-256 hex of [content]. Used to tell "changed" from "re-written with
/// the same bytes" without keeping copies.
String contentHash(String content) =>
    sha256.convert(utf8.encode(content)).toString();

/// What the remote held for one file at the last pull.
class JournalEntry {
  final String version;
  final String contentHash;

  const JournalEntry({required this.version, required this.contentHash});

  Map<String, dynamic> toJson() => {
    'version': version,
    'content_hash': contentHash,
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
    version: json['version'] as String,
    contentHash: json['content_hash'] as String,
  );

  @override
  bool operator ==(Object other) =>
      other is JournalEntry &&
      other.version == version &&
      other.contentHash == contentHash;

  @override
  int get hashCode => Object.hash(version, contentHash);
}

/// The persisted sync state of one remote vault: `sync.json`.
///
/// Written after every state change so a crash at any point loses nothing.
/// As the mirror's [WorkspaceChangeListener] it marks a file dirty before
/// the write lands.
class SyncJournal implements WorkspaceChangeListener {
  /// Null for an in-memory journal (tests): [save] is then a no-op.
  final String? filePath;

  /// Remote version and content hash per file, as of the last pull.
  final Map<String, JournalEntry> baseline = {};

  /// Files changed locally since the last successful push.
  final Set<String> dirty = {};

  DateTime? lastPullAt;
  DateTime? lastPushAt;
  String? lastError;

  /// True when the journal file was unreadable. The engine then treats
  /// every mirror file as dirty on the next pull, so a stale baseline can
  /// never make it overwrite local edits.
  bool needsFullRescan = false;

  /// Called after a name is marked dirty. The scheduler hooks in here.
  void Function(String name)? onDirty;

  SyncJournal({this.filePath});

  static Future<SyncJournal> load(String filePath) async {
    final journal = SyncJournal(filePath: filePath);
    final file = File(filePath);
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('journal is not a JSON object');
        }
        journal._apply(decoded);
      } catch (e) {
        log('Unreadable sync journal $filePath ($e); rescanning',
            name: 'flatplan.sync');
        journal.baseline.clear();
        journal.dirty.clear();
        journal.lastPullAt = null;
        journal.lastPushAt = null;
        journal.lastError = null;
        journal.needsFullRescan = true;
      }
    }
    return journal;
  }

  @override
  Future<void> onChanged(String name) async {
    dirty.add(name);
    await save();
    onDirty?.call(name);
  }

  /// Serialises [save]: a local edit and an in-flight sync both save, and
  /// two overlapping saves would fight over the same temp file.
  Future<void> _saveTail = Future.value();

  Future<void> save() {
    final next = _saveTail.then((_) => _writeFile());
    // The tail must never carry an error forward, or every later save fails.
    _saveTail = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _writeFile() async {
    final path = filePath;
    if (path == null) return;
    final file = File(path);
    await file.parent.create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(jsonEncode(toJson()), flush: true);
    await tmp.rename(path);
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'baseline': {for (final e in baseline.entries) e.key: e.value.toJson()},
    'dirty': dirty.toList()..sort(),
    'last_pull_at': lastPullAt?.toIso8601String(),
    'last_push_at': lastPushAt?.toIso8601String(),
    'last_error': lastError,
  };

  void _apply(Map<String, dynamic> json) {
    final base = json['baseline'] as Map<String, dynamic>? ?? {};
    for (final e in base.entries) {
      baseline[e.key] = JournalEntry.fromJson(e.value as Map<String, dynamic>);
    }
    dirty.addAll((json['dirty'] as List<dynamic>? ?? []).cast<String>());
    lastPullAt = _date(json['last_pull_at']);
    lastPushAt = _date(json['last_push_at']);
    lastError = json['last_error'] as String?;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
