import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The few app-support locations the storage layer needs, derived from one
/// root so tests can point everything at a temp directory.
class AppPaths {
  final String appSupportDir;

  const AppPaths({required this.appSupportDir});

  /// `<app support>/vaults.json`
  String get registryFile => p.join(appSupportDir, 'vaults.json');

  /// `<app support>/periods`, the pre-vault default folder. Kept as the
  /// default vault's path so nothing moves on upgrade.
  String get defaultPeriodsDir => p.join(appSupportDir, 'periods');

  /// `<app support>/vaults`, the root of every per-vault private area.
  String get vaultsDir => p.join(appSupportDir, 'vaults');

  String privateAreaFor(String vaultId) => p.join(vaultsDir, vaultId);

  String mirrorFor(String vaultId) => p.join(privateAreaFor(vaultId), 'files');

  String journalFor(String vaultId) =>
      p.join(privateAreaFor(vaultId), 'sync.json');

  /// Resolves the real application support directory. Writable on every
  /// platform, including MSIX-packaged Windows apps.
  static Future<AppPaths> resolve() async {
    final dir = await getApplicationSupportDirectory();
    return AppPaths(appSupportDir: dir.path);
  }
}
