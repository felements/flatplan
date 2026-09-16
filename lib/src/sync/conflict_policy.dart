import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../storage/period_stats_writer.dart';

/// How the engine settles a file edited on both sides since the last pull.
///
/// Newest [timestampOf] wins; the loser is kept as a side file. When a
/// timestamp is missing on either side, local wins. [derivedFiles] are
/// regenerated from other data, so local wins silently with no side file.
class ConflictPolicy {
  final DateTime? Function(String name, String content) timestampOf;
  final Set<String> derivedFiles;
  final DateTime Function() now;

  const ConflictPolicy({
    required this.timestampOf,
    this.derivedFiles = const {},
    this.now = DateTime.now,
  });
}

/// Reads `last_modified` from a period YAML file. Null for anything else,
/// including unreadable YAML.
DateTime? periodLastModified(String name, String content) {
  if (!name.endsWith('.yaml')) return null;
  try {
    final doc = loadYaml(content);
    if (doc is! YamlMap) return null;
    final value = doc['last_modified'];
    return value is String ? DateTime.tryParse(value) : null;
  } on YamlException {
    return null;
  }
}

/// The app's policy: period files carry `last_modified`; the stats file is
/// derived.
final periodConflictPolicy = ConflictPolicy(
  timestampOf: periodLastModified,
  derivedFiles: {PeriodStatsWriter.fileName},
);

/// `2026-09-september.yaml` at 2026-09-16 14:32 becomes
/// `2026-09-september.conflict-2026-09-16-1432.yaml`.
String conflictFileName(String name, DateTime at) {
  final ext = p.extension(name);
  final stem = p.basenameWithoutExtension(name);
  final stamp = DateFormat('yyyy-MM-dd-HHmm').format(at);
  return '$stem.conflict-$stamp$ext';
}
