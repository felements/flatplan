import 'dart:convert';
import 'dart:io';

import 'package:flatplan/src/sync/gitlab/git_blob.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A scripted GitLab: enough of the REST API for FlatPlan, in memory.
class FakeGitLab {
  static const baseUrl = 'https://gitlab.test';

  /// Repository files by full path, e.g. `budget/2026-09-september.yaml`.
  final Map<String, String> files = {};
  final List<String> branches = ['main'];
  bool emptyRepo = false;
  int projectId = 42;
  String projectPath = 'group/repo';
  String projectName = 'repo';
  String defaultBranch = 'main';

  /// Projects returned by the search, in order. Defaults to the one above.
  List<Map<String, dynamic>>? searchResults;

  String validToken = 'glpat-secret';
  List<String> tokenScopes = ['api'];
  bool fineGrained = false;

  /// When set, `/personal_access_tokens/self` answers with this status.
  int? tokenInfoStatus;

  /// Path prefix -> status code, to force errors on specific endpoints.
  final Map<String, int> failWith = {};

  /// When set, every request throws it (offline).
  Object? throwOnRequest;

  /// Message returned with a forced 400 on commit.
  String commitErrorMessage = 'You are not allowed to push into this branch';

  /// The `commit_message` of every commit actually sent, in order.
  final List<String> commitMessages = [];

  /// Every request, as `METHOD path?query`.
  final List<String> calls = [];
  int treePageSize = 100;

  late final http.Client client = MockClient(_handle);

  Map<String, dynamic> get _projectJson => {
    'id': projectId,
    'name': projectName,
    'path_with_namespace': projectPath,
    'default_branch': defaultBranch,
    'empty_repo': emptyRepo,
  };

  Future<http.Response> _handle(http.Request request) async {
    final error = throwOnRequest;
    if (error != null) throw error;
    final path = request.url.path;
    calls.add('${request.method} $path${request.url.hasQuery ? '?${request.url.query}' : ''}');

    if (request.headers['PRIVATE-TOKEN'] != validToken) {
      return _json(401, {'message': '401 Unauthorized'});
    }
    for (final entry in failWith.entries) {
      if (path.startsWith('/api/v4${entry.key}')) {
        return _json(entry.value, {'message': 'forced ${entry.value}'});
      }
    }

    final p = '/api/v4/projects/$projectId';
    if (path == '/api/v4/projects' && request.method == 'GET') {
      final results = searchResults ?? [_projectJson];
      final q = request.url.queryParameters['search'] ?? '';
      return _json(200, [
        for (final r in results)
          if ((r['path_with_namespace'] as String).contains(q) ||
              (r['name'] as String).contains(q))
            r,
      ]);
    }
    if (path == '/api/v4/projects/${Uri.encodeComponent(projectPath)}' ||
        path == '/api/v4/projects/$projectPath') {
      return _json(200, _projectJson);
    }
    if (path == p) return _json(200, _projectJson);
    if (path == '$p/repository/branches') {
      return _json(200, [for (final b in branches) {'name': b}]);
    }
    if (path.startsWith('$p/repository/branches/')) {
      final name = Uri.decodeComponent(path.split('/').last);
      return branches.contains(name)
          ? _json(200, {'name': name})
          : _json(404, {'message': '404 Branch Not Found'});
    }
    if (path == '$p/repository/tree') return _tree(request);
    if (path.startsWith('$p/repository/files/') && path.endsWith('/raw')) {
      final encoded = path.substring('$p/repository/files/'.length, path.length - '/raw'.length);
      final filePath = Uri.decodeComponent(encoded);
      final content = files[filePath];
      if (content == null) return _json(404, {'message': '404 File Not Found'});
      return http.Response(content, 200, headers: {
        'x-gitlab-blob-id': gitBlobSha(content),
        'content-type': 'text/plain; charset=utf-8',
      });
    }
    if (path == '$p/repository/commits' && request.method == 'POST') {
      return _commit(request);
    }
    if (path == '/api/v4/personal_access_tokens/self') {
      final status = tokenInfoStatus;
      if (status != null) return _json(status, {'message': 'forced $status'});
      return _json(200, {
        'id': 1,
        'scopes': fineGrained ? <String>[] : tokenScopes,
        if (fineGrained)
          'granular_scopes': [
            {'access': 'selected_memberships', 'permissions': ['read_repository'], 'project_id': projectId, 'group_id': null},
          ],
      });
    }
    return _json(404, {'message': '404 Not Found'});
  }

  http.Response _tree(http.Request request) {
    if (emptyRepo) return _json(404, {'message': '404 Tree Not Found'});
    final ref = request.url.queryParameters['ref'];
    if (ref != null && !branches.contains(ref)) {
      return _json(404, {'message': '404 Tree Not Found'});
    }
    final folder = request.url.queryParameters['path'] ?? '';
    final prefix = folder.isEmpty ? '' : '$folder/';
    final entries = <Map<String, dynamic>>[];
    final seenDirs = <String>{};
    for (final path in files.keys.toList()..sort()) {
      if (!path.startsWith(prefix)) continue;
      final rest = path.substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash == -1) {
        entries.add({'id': gitBlobSha(files[path]!), 'name': rest, 'type': 'blob', 'path': path, 'mode': '100644'});
      } else {
        final dir = rest.substring(0, slash);
        if (seenDirs.add(dir)) {
          entries.add({'id': 'tree-$dir', 'name': dir, 'type': 'tree', 'path': '$prefix$dir', 'mode': '040000'});
        }
      }
    }
    if (folder.isNotEmpty && entries.isEmpty) {
      return _json(404, {'message': '404 Tree Not Found'});
    }
    final page = int.parse(request.url.queryParameters['page'] ?? '1');
    final start = (page - 1) * treePageSize;
    final slice = entries.skip(start).take(treePageSize).toList();
    final hasNext = start + treePageSize < entries.length;
    return http.Response(jsonEncode(slice), 200, headers: {
      'content-type': 'application/json',
      'x-next-page': hasNext ? '${page + 1}' : '',
    });
  }

  http.Response _commit(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final branch = body['branch'] as String;
    if (failWith.containsKey('/commit-refused')) {
      return _json(400, {'message': commitErrorMessage});
    }
    commitMessages.add(body['commit_message'] as String);
    final actions = (body['actions'] as List).cast<Map<String, dynamic>>();
    for (final a in actions) {
      final path = a['file_path'] as String;
      switch (a['action']) {
        case 'create':
          if (files.containsKey(path)) {
            return _json(400, {'message': 'A file with this name already exists'});
          }
          files[path] = a['content'] as String;
        case 'update':
          if (!files.containsKey(path)) {
            return _json(400, {'message': "A file with this name doesn't exist"});
          }
          files[path] = a['content'] as String;
        case 'delete':
          if (!files.containsKey(path)) {
            return _json(400, {'message': "A file with this name doesn't exist"});
          }
          files.remove(path);
      }
    }
    if (emptyRepo) {
      emptyRepo = false;
      if (!branches.contains(branch)) branches.add(branch);
    }
    return _json(201, {'id': 'commit-${calls.length}'});
  }

  static http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

/// The error the http package throws for a dropped socket.
Object socketDropped() => const SocketException('connection refused');
