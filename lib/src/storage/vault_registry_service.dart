import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'app_paths.dart';

/// The pre-vault configuration: one folder plus its macOS bookmark.
class LegacyStorageSettings {
  final String path;
  final String? bookmark;

  const LegacyStorageSettings({required this.path, this.bookmark});
}

/// Reads and writes `vaults.json`, and creates it on first launch from the
/// pre-vault settings.
class VaultRegistryService {
  static const legacyPathKey = 'data_directory';
  static const legacyBookmarkKey = 'data_directory_bookmark';
  static const defaultVaultName = 'My budget';

  final AppPaths paths;
  final Future<LegacyStorageSettings?> Function() _readLegacy;
  final Future<void> Function() _clearLegacy;
  final String Function() _newId;

  VaultRegistryService({
    required this.paths,
    required Future<LegacyStorageSettings?> Function() readLegacy,
    required Future<void> Function() clearLegacy,
    String Function()? newId,
  }) : _readLegacy = readLegacy,
       _clearLegacy = clearLegacy,
       _newId = newId ?? (() => const Uuid().v4());

  /// Production wiring: legacy settings come from shared_preferences.
  factory VaultRegistryService.withSharedPreferences(AppPaths paths) {
    return VaultRegistryService(
      paths: paths,
      readLegacy: () async {
        final prefs = await SharedPreferences.getInstance();
        final path = prefs.getString(legacyPathKey);
        if (path == null || path.isEmpty) return null;
        return LegacyStorageSettings(
          path: path,
          bookmark: prefs.getString(legacyBookmarkKey),
        );
      },
      clearLegacy: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(legacyPathKey);
        await prefs.remove(legacyBookmarkKey);
      },
    );
  }

  File get _file => File(paths.registryFile);

  /// Loads the registry, or creates it from the legacy settings (or the
  /// default folder) when absent. A corrupt file is moved to
  /// `vaults.json.broken` and reported through
  /// [VaultRegistry.brokenRegistryFile].
  Future<VaultRegistry> loadOrCreate() async {
    String? brokenFile;
    if (await _file.exists()) {
      try {
        final decoded = jsonDecode(await _file.readAsString());
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('registry is not a JSON object');
        }
        return VaultRegistry.fromJson(decoded);
      } catch (e) {
        brokenFile = '${paths.registryFile}.broken';
        log('Corrupt vault registry ($e), moving to $brokenFile',
            name: 'flatplan.storage');
        await _file.rename(brokenFile);
      }
    }

    final registry = await _bootstrap();
    await save(registry);
    // Only forget the legacy keys once the new registry is safely on disk,
    // so a failed first launch can retry the migration.
    await _clearLegacy();
    return registry.copyWith(brokenRegistryFile: brokenFile);
  }

  Future<VaultRegistry> _bootstrap() async {
    final legacy = await _readLegacy();
    final id = _newId();
    final Vault vault;
    if (legacy != null) {
      vault = Vault(
        id: id,
        name: p.basename(legacy.path),
        location: VaultLocation.local(
          path: legacy.path,
          bookmark: legacy.bookmark,
        ),
        createdAt: DateTime.now(),
      );
    } else {
      vault = Vault(
        id: id,
        name: defaultVaultName,
        location: VaultLocation.local(path: paths.defaultPeriodsDir),
        createdAt: DateTime.now(),
      );
    }
    return VaultRegistry(lastSelectedVaultId: id, vaults: [vault]);
  }

  /// Writes atomically: temp file, then rename over the registry.
  Future<void> save(VaultRegistry registry) async {
    await _file.parent.create(recursive: true);
    final tmp = File('${paths.registryFile}.tmp');
    const encoder = JsonEncoder.withIndent('  ');
    await tmp.writeAsString(encoder.convert(registry.toJson()), flush: true);
    await tmp.rename(paths.registryFile);
  }
}
