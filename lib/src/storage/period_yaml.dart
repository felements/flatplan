import 'dart:convert';

import 'package:json2yaml/json2yaml.dart';
import 'package:yaml/yaml.dart';

/// Encodes a period's JSON map as YAML that reads back to the same values.
///
/// `json2yaml` lays the file out, but its quoting misses cases: a string
/// starting with `#` is written bare and read back as a comment (a payment
/// comment of "#renovation tiles" would vanish), and a string with a `"` in
/// it is wrapped in quotes without escaping, which breaks the whole file.
///
/// Strings `json2yaml` would get wrong are written as JSON strings instead —
/// JSON's double-quoted form is valid YAML. Everything else comes out byte
/// for byte as before, so existing files do not change on their next save.
/// The result is read back once; should it still differ, every string is
/// written as JSON so nothing can be lost.
String encodePeriodYaml(Map<String, dynamic> map) {
  final yaml = _encode(map, quoteAll: false);
  if (_readsBackAs(yaml, map)) return yaml;
  return _encode(map, quoteAll: true);
}

String _encode(Map<String, dynamic> map, {required bool quoteAll}) {
  final quoted = <String>[];

  dynamic protect(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): protect(entry.value),
      };
    }
    if (value is List) return [for (final item in value) protect(item)];
    if (value is String && (quoteAll || _needsOwnQuoting(value))) {
      // A private-use marker json2yaml writes bare, swapped for the quoted
      // string once the layout is done.
      final token = '\u{E000}${quoted.length}\u{E000}';
      quoted.add(_yamlQuoted(value));
      return token;
    }
    return value;
  }

  final yaml = json2yaml(
    protect(map) as Map<String, dynamic>,
    yamlStyle: YamlStyle.generic,
  );
  if (quoted.isEmpty) return yaml;
  return yaml.replaceAllMapped(_token, (m) => quoted[int.parse(m[1]!)]);
}

final _token = RegExp('\u{E000}(\\d+)\u{E000}');

/// Empty, padded, starting with a YAML indicator, ending in `:`, holding a
/// quote, backslash or control character, or spanning lines.
final _risky = RegExp(
  r'''^$|^\s|\s$|^[-?:,\[\]{}#&*!|>'"%@`]|:$|["\\]|[\x00-\x1F\x7F\u0085\u2028\u2029]''',
);

/// Plain words YAML reads as null, a boolean or a number although Dart's
/// number parser (which json2yaml asks) does not.
final _yamlWord = RegExp(
  r'^(~|null|Null|NULL|true|True|TRUE|false|False|FALSE|[-+]?\.(inf|Inf|INF)|\.(nan|NaN|NAN)|0o[0-7]+)$',
);

bool _needsOwnQuoting(String value) =>
    _risky.hasMatch(value) || _yamlWord.hasMatch(value);

/// A YAML double-quoted scalar: JSON's escaping, plus the characters YAML
/// treats as line breaks or non-printable that JSON leaves alone.
String _yamlQuoted(String value) => jsonEncode(value)
    .replaceAll('\x7F', r'\x7F')
    .replaceAll('\u0085', r'\u0085')
    .replaceAll('\u2028', r'\u2028')
    .replaceAll('\u2029', r'\u2029');

bool _readsBackAs(String yaml, Map<String, dynamic> map) {
  try {
    return _sameData(loadYaml(yaml), map);
  } on YamlException {
    return false;
  }
}

/// Whether [read] holds what [written] did. json2yaml writes an empty list
/// or map as nothing, which reads back as null, and that is no loss.
bool _sameData(dynamic read, dynamic written) {
  if (written is Map) {
    if (written.isEmpty) return read == null || (read is Map && read.isEmpty);
    if (read is! Map || read.length != written.length) return false;
    return written.entries.every(
      (e) => read.containsKey(e.key) && _sameData(read[e.key], e.value),
    );
  }
  if (written is List) {
    if (written.isEmpty) return read == null || (read is List && read.isEmpty);
    if (read is! List || read.length != written.length) return false;
    for (var i = 0; i < written.length; i++) {
      if (!_sameData(read[i], written[i])) return false;
    }
    return true;
  }
  return read == written;
}
