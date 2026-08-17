import 'dart:collection';
import 'dart:developer' show log;
import 'dart:io';

import 'package:json2yaml/json2yaml.dart';
import 'package:yaml/yaml.dart';

import '../models/models.dart';

/// Repository for handling local YAML storage of tracking periods.
class PeriodRepository {
  /// The absolute path to the directory where period YAML files are stored.
  final String directoryPath;

  /// Cache of period ID to its physical filename to preserve filenames on save.
  final Map<String, String> _idToFilename = {};

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

  /// Loads all periods from the local YAML files.
  Future<List<Period>> loadAllPeriods() async {
    final dir = await _getStorageDirectory();
    final periods = <Period>[];
    _idToFilename.clear();

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.yaml')) {
        try {
          final content = await entity.readAsString();
          if (content.trim().isEmpty) continue;

          final yamlDoc = loadYaml(content);
          if (yamlDoc is! YamlMap) {
            log(
              'Skipped ${entity.path}: not a valid YamlMap object.',
              name: 'flatplan.storage',
            );
            continue;
          }
          final map = _cloneYamlNode(yamlDoc) as Map<String, dynamic>;
          final period = Period.fromJson(map);
          _idToFilename[period.id] = entity.uri.pathSegments.last;
          periods.add(period);
        } catch (e) {
          // Log or handle corrupt YAML files if needed
          log(
            'Failed to load period from ${entity.path}: $e',
            name: 'flatplan.storage',
          );
        }
      }
    }
    return periods;
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

    if (sanitizedName.contains('template')) {
      return '$sanitizedName.yaml';
    } else {
      final yyyy = period.startDate.year.toString();
      final mm = period.startDate.month.toString().padLeft(2, '0');
      return '$yyyy-$mm-$sanitizedName.yaml';
    }
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
