import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Git's blob object id for [content]: SHA-1 of `"blob <len>\0" + bytes`.
/// Equal to the `id` the GitLab tree endpoint returns for a file, so a
/// push can report the new version of a file without another request.
String gitBlobSha(String content) {
  final bytes = utf8.encode(content);
  final header = utf8.encode('blob ${bytes.length}\x00');
  return sha1.convert([...header, ...bytes]).toString();
}
