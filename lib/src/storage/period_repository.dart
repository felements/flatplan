import 'dart:collection';
import 'dart:io';

import 'package:json2yaml/json2yaml.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';

import '../models/models.dart';

/// Repository for handling local YAML storage of tracking periods.
class PeriodRepository {
  Future<Directory> _getStorageDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/flatplan/periods');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Loads all periods from the local YAML files.
  Future<List<Period>> loadAllPeriods() async {
    final dir = await _getStorageDirectory();
    final periods = <Period>[];

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.yaml')) {
        try {
          final content = await entity.readAsString();
          if (content.trim().isEmpty) continue;

          final yamlDoc = loadYaml(content);
          final map = _cloneYamlNode(yamlDoc) as Map<String, dynamic>;
          periods.add(Period.fromJson(map));
        } catch (e) {
          // Log or handle corrupt YAML files if needed
          print('Failed to load period from ${entity.path}: $e');
        }
      }
    }
    return periods;
  }

  /// Saves a period to a local YAML file.
  Future<void> savePeriod(Period period) async {
    final dir = await _getStorageDirectory();
    final file = File('${dir.path}/${period.id}.yaml');

    final jsonMap = period.toJson();
    final sortedMap = _sortKeysAlphabetically(jsonMap);

    // json2yaml formatting generates clean YAML output.
    final yamlString = json2yaml(sortedMap, yamlStyle: YamlStyle.generic);
    await file.writeAsString(yamlString);
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
