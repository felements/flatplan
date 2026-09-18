import 'vault_workspace.dart';

/// Writes/removes the single current-period stats snapshot next to the
/// period YAML files, so it rides along with the vault.
class PeriodStatsWriter {
  static const fileName = 'current_stats.md';

  /// The one line that changes on every regeneration.
  static final _generatedLine = RegExp(r'^- Generated: .*$', multiLine: true);

  final VaultWorkspace workspace;

  PeriodStatsWriter({required this.workspace});

  /// True when [a] and [b] differ in nothing but their "Generated" line.
  static bool sameExceptGenerated(String a, String b) =>
      a.replaceFirst(_generatedLine, '') == b.replaceFirst(_generatedLine, '');

  /// Writes [markdown] unless the file already says the same thing. A
  /// regeneration that only moved the timestamp would otherwise mark the
  /// vault dirty and push a commit that changes nothing.
  Future<void> writeStatsFile(String markdown) async {
    if (await workspace.exists(fileName)) {
      final existing = await workspace.readString(fileName);
      if (sameExceptGenerated(existing, markdown)) return;
    }
    await workspace.writeString(fileName, markdown);
  }

  Future<void> deleteStatsFile() async {
    if (await workspace.exists(fileName)) {
      await workspace.delete(fileName);
    }
  }
}
