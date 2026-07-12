import 'dart:io';

/// Writes/removes the single current-period stats snapshot next to the
/// period YAML files, so it rides along with the user's git workflow.
class PeriodStatsWriter {
  static const fileName = 'current_stats.md';

  final String directoryPath;

  PeriodStatsWriter({required this.directoryPath});

  File get _file => File('$directoryPath/$fileName');

  Future<void> writeStatsFile(String markdown) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _file.writeAsString(markdown);
  }

  Future<void> deleteStatsFile() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }
}
