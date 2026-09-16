import 'vault_workspace.dart';

/// Writes/removes the single current-period stats snapshot next to the
/// period YAML files, so it rides along with the vault.
class PeriodStatsWriter {
  static const fileName = 'current_stats.md';

  final VaultWorkspace workspace;

  PeriodStatsWriter({required this.workspace});

  Future<void> writeStatsFile(String markdown) =>
      workspace.writeString(fileName, markdown);

  Future<void> deleteStatsFile() async {
    if (await workspace.exists(fileName)) {
      await workspace.delete(fileName);
    }
  }
}
