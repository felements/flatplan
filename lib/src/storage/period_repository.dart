import 'dart:collection';
import 'dart:developer' show log;
import 'dart:io';

import 'package:json2yaml/json2yaml.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart';

import '../models/models.dart';

/// A period file that could not be read back into a [Period].
///
/// The file is left untouched on disk so the user can repair it.
class PeriodLoadFailure {
  /// The file's name within the storage directory, e.g. `2026-03-march.yaml`.
  final String fileName;

  /// The file's absolute path.
  final String path;

  /// A human-readable reason the file could not be read, including the
  /// line and column when the YAML parser reported one.
  final String message;

  const PeriodLoadFailure({
    required this.fileName,
    required this.path,
    required this.message,
  });

  @override
  bool operator ==(Object other) =>
      other is PeriodLoadFailure &&
      other.fileName == fileName &&
      other.path == path &&
      other.message == message;

  @override
  int get hashCode => Object.hash(fileName, path, message);
}

/// The outcome of reading every period file in the storage directory:
/// the periods that loaded, plus the files that did not.
class PeriodLoadResult {
  final List<Period> periods;
  final List<PeriodLoadFailure> failures;

  const PeriodLoadResult({required this.periods, required this.failures});

  bool get hasFailures => failures.isNotEmpty;
}

/// Repository for handling local YAML storage of tracking periods.
class PeriodRepository {
  /// The absolute path to the directory where period YAML files are stored.
  final String directoryPath;

  /// Cache of period ID to its physical filename to preserve filenames on save.
  final Map<String, String> _idToFilename = {};

  /// Filenames that failed to load, reserved so [savePeriod] never overwrites
  /// a file the user may still be able to repair.
  final Set<String> _failedFilenames = {};

  PeriodRepository({required this.directoryPath});

  /// The physical YAML filename for [periodId], or null if the period has
  /// not been loaded or saved by this repository instance yet.
  String? filenameForPeriod(String periodId) => _idToFilename[periodId];

  Future<Directory> _getStorageDirectory() async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Loads all periods from the local YAML files, discarding any files that
  /// could not be read. Use [loadAll] to also learn which files failed.
  Future<List<Period>> loadAllPeriods() async => (await loadAll()).periods;

  /// Loads all periods from the local YAML files, reporting unreadable files
  /// as [PeriodLoadFailure]s rather than silently dropping them.
  Future<PeriodLoadResult> loadAll() async {
    final dir = await _getStorageDirectory();
    final periods = <Period>[];
    final failures = <PeriodLoadFailure>[];
    _idToFilename.clear();
    _failedFilenames.clear();

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.yaml')) {
        final fileName = entity.uri.pathSegments.last;
        try {
          final content = await entity.readAsString();
          if (content.trim().isEmpty) continue;

          final yamlDoc = loadYaml(content);
          if (yamlDoc is! YamlMap) {
            throw const FormatException('top level is not a mapping');
          }
          final map = _cloneYamlNode(yamlDoc) as Map<String, dynamic>;
          final period = Period.fromJson(map);
          _idToFilename[period.id] = fileName;
          periods.add(period);
        } catch (e) {
          final message = _describeLoadError(e);
          _failedFilenames.add(fileName);
          failures.add(
            PeriodLoadFailure(
              fileName: fileName,
              path: entity.path,
              message: message,
            ),
          );
          log(
            'Failed to load period from ${entity.path}: $message',
            name: 'flatplan.storage',
          );
        }
      }
    }

    failures.sort((a, b) => a.fileName.compareTo(b.fileName));
    return PeriodLoadResult(periods: periods, failures: failures);
  }

  /// Turns a load error into a message a user can act on.
  String _describeLoadError(Object error) {
    if (error is YamlException) {
      final span = error.span;
      if (span != null) {
        return 'line ${span.start.line + 1}, '
            'column ${span.start.column + 1}: ${error.message}';
      }
      return error.message;
    }
    if (error is CheckedFromJsonException) {
      final field = error.key;
      final detail = error.message ?? error.innerError?.toString() ?? '';
      return field == null
          ? 'invalid period data: $detail'
          : 'invalid or missing field "$field": $detail';
    }
    if (error is FormatException) {
      return error.message;
    }
    return error.toString();
  }

  /// Saves a period to a local YAML file.
  Future<void> savePeriod(Period period) async {
    final dir = await _getStorageDirectory();

    // Keep existing filename if loaded, otherwise generate a new one
    final filename = _idToFilename[period.id] ?? _generateFilename(period);
    _idToFilename[period.id] = filename;

    final file = File('${dir.path}/$filename');

    // Remove legacy file if it exists to avoid duplicates
    final legacyFile = File('${dir.path}/${period.id}.yaml');
    if (await legacyFile.exists() && legacyFile.path != file.path) {
      await legacyFile.delete();
    }

    final jsonMap = period.toJson();
    final sortedMap = _sortKeysAlphabetically(jsonMap);

    // json2yaml formatting generates clean YAML output.
    final yamlString = json2yaml(sortedMap, yamlStyle: YamlStyle.generic);
    await file.writeAsString(yamlString);
  }

  String _generateFilename(Period period) {
    var sanitizedName = period.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (sanitizedName.isEmpty) {
      sanitizedName = period.id;
    }

    final String base;
    if (sanitizedName.contains('template')) {
      base = sanitizedName;
    } else {
      final yyyy = period.startDate.year.toString();
      final mm = period.startDate.month.toString().padLeft(2, '0');
      base = '$yyyy-$mm-$sanitizedName';
    }

    return _firstUnreservedFilename(base);
  }

  /// Returns `$base.yaml`, or a numbered variant when that name belongs to a
  /// file that failed to load and must not be overwritten.
  String _firstUnreservedFilename(String base) {
    var candidate = '$base.yaml';
    var suffix = 2;
    while (_failedFilenames.contains(candidate)) {
      candidate = '$base-$suffix.yaml';
      suffix++;
    }
    return candidate;
  }

  /// recursively converts YamlMap/YamlList to standard Dart Map/List
  dynamic _cloneYamlNode(dynamic node) {
    if (node is YamlMap) {
      final map = <String, dynamic>{};
      node.forEach((key, value) {
        map[key.toString()] = _cloneYamlNode(value);
      });
      return map;
    } else if (node is YamlList) {
      return node.map((e) => _cloneYamlNode(e)).toList();
    } else {
      return node;
    }
  }

  /// Recursively sorts map keys alphabetically, leaving lists in original order.
  dynamic _sortKeysAlphabetically(dynamic node) {
    if (node is Map) {
      final sorted = SplayTreeMap<String, dynamic>();
      node.forEach((k, v) {
        if (v != null) {
          sorted[k.toString()] = _sortKeysAlphabetically(v);
        }
      });
      return sorted;
    } else if (node is List) {
      return node.map((e) => _sortKeysAlphabetically(e)).toList();
    }
    return node;
  }
}
