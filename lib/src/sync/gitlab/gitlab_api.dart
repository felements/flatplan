import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../remote_store.dart';

/// A non-2xx answer other than 401 and the "come back later" statuses.
class GitLabApiException implements Exception {
  final int status;
  final String message;

  const GitLabApiException(this.status, this.message);

  @override
  String toString() => message;
}

/// The server presented a certificate the system does not trust and that
/// does not match the vault's pinned fingerprint. Carries what the user
/// needs to decide whether to trust it.
class CertificateRejected implements Exception {
  final String host;
  final String subject;
  final String fingerprint;

  const CertificateRejected({
    required this.host,
    required this.subject,
    required this.fingerprint,
  });

  @override
  String toString() =>
      'The certificate of $host is not trusted. '
      'Trust it in the vault settings.';
}

class ProjectSummary {
  final int id;
  final String name;
  final String pathWithNamespace;
  final String defaultBranch;
  final bool emptyRepo;

  const ProjectSummary({
    required this.id,
    required this.name,
    required this.pathWithNamespace,
    required this.defaultBranch,
    required this.emptyRepo,
  });

  factory ProjectSummary.fromJson(Map<String, dynamic> json) => ProjectSummary(
    id: json['id'] as int,
    name: json['name'] as String,
    pathWithNamespace: json['path_with_namespace'] as String,
    defaultBranch: json['default_branch'] as String? ?? 'main',
    emptyRepo: json['empty_repo'] as bool? ?? false,
  );
}

class TreeEntry {
  final String id;
  final String name;
  final String type;
  final String path;

  const TreeEntry({required this.id, required this.name, required this.type, required this.path});

  bool get isBlob => type == 'blob';

  factory TreeEntry.fromJson(Map<String, dynamic> json) => TreeEntry(
    id: json['id'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    path: json['path'] as String,
  );
}

class RawFile {
  final String content;
  final String blobId;

  const RawFile({required this.content, required this.blobId});
}

class CommitAction {
  final String action; // create | update | delete
  final String filePath;
  final String? content;

  const CommitAction({required this.action, required this.filePath, this.content});

  Map<String, dynamic> toJson() => {
    'action': action,
    'file_path': filePath,
    if (content != null) 'content': content,
  };
}

class TokenInfo {
  final List<String> scopes;

  /// True for a fine-grained token, which reports `granular_scopes`
  /// instead of `scopes`.
  final bool isFineGrained;

  const TokenInfo({required this.scopes, required this.isFineGrained});
}

/// Thin typed client over the GitLab REST API v4. Every method throws
/// [RemoteUnreachable], [RemoteAuthRejected], [CertificateRejected] or
/// [GitLabApiException]; nothing else escapes.
class GitLabApi {
  final http.Client client;
  final String baseUrl;
  final String token;
  final Duration timeout;

  /// Set by the pinned client: returns and clears the certificate it just
  /// rejected, so a handshake failure can be reported as an offer to trust.
  final CertificateRejected? Function()? takeRejectedCertificate;

  GitLabApi({
    required this.client,
    required this.baseUrl,
    required this.token,
    this.timeout = const Duration(seconds: 30),
    this.takeRejectedCertificate,
  });

  Future<List<ProjectSummary>> searchProjects(String query) async {
    final body = await _getJson('/projects', {
      'membership': 'true',
      'min_access_level': '30',
      'simple': 'true',
      'search_namespaces': 'true',
      'order_by': 'last_activity_at',
      'per_page': '50',
      'search': query,
    });
    return [for (final p in body as List) ProjectSummary.fromJson(p as Map<String, dynamic>)];
  }

  Future<ProjectSummary> projectByPath(String path) async =>
      ProjectSummary.fromJson(await _getJson('/projects/${Uri.encodeComponent(path)}') as Map<String, dynamic>);

  Future<ProjectSummary> project(int id) async =>
      ProjectSummary.fromJson(await _getJson('/projects/$id') as Map<String, dynamic>);

  Future<List<String>> branches(int id) async {
    final body = await _getJson('/projects/$id/repository/branches', {'per_page': '100'});
    return [for (final b in body as List) (b as Map<String, dynamic>)['name'] as String];
  }

  Future<bool> branchExists(int id, String name) async {
    try {
      await _getJson('/projects/$id/repository/branches/${Uri.encodeComponent(name)}');
      return true;
    } on GitLabApiException catch (e) {
      if (e.status == 404) return false;
      rethrow;
    }
  }

  Future<List<TreeEntry>> tree(int id, String ref, String path) async {
    final entries = <TreeEntry>[];
    var page = 1;
    while (true) {
      final response = await _send('GET', '/projects/$id/repository/tree', query: {
        'ref': ref,
        'path': path,
        'per_page': '100',
        'page': '$page',
      });
      entries.addAll([
        for (final e in jsonDecode(response.body) as List) TreeEntry.fromJson(e as Map<String, dynamic>),
      ]);
      final next = response.headers['x-next-page'];
      if (next == null || next.isEmpty) return entries;
      page = int.parse(next);
    }
  }

  Future<RawFile> rawFile(int id, String ref, String path) async {
    final response = await _send(
      'GET',
      '/projects/$id/repository/files/${Uri.encodeComponent(path)}/raw',
      query: {'ref': ref},
    );
    final blobId = response.headers['x-gitlab-blob-id'];
    if (blobId == null) {
      throw GitLabApiException(response.statusCode, 'GitLab did not return a blob id for $path');
    }
    return RawFile(content: utf8.decode(response.bodyBytes), blobId: blobId);
  }

  Future<String> commit(int id, String branch, String message, List<CommitAction> actions) async {
    final body = await _postJson('/projects/$id/repository/commits', {
      'branch': branch,
      'commit_message': message,
      'actions': [for (final a in actions) a.toJson()],
    });
    return (body as Map<String, dynamic>)['id'] as String;
  }

  Future<TokenInfo> tokenInfo() async {
    final body = await _getJson('/personal_access_tokens/self') as Map<String, dynamic>;
    return TokenInfo(
      scopes: ((body['scopes'] as List?) ?? const []).cast<String>(),
      isFineGrained: body['granular_scopes'] != null,
    );
  }

  Future<Object?> _getJson(String path, [Map<String, String>? query]) async =>
      jsonDecode((await _send('GET', path, query: query)).body);

  Future<Object?> _postJson(String path, Map<String, dynamic> body) async =>
      jsonDecode((await _send('POST', path, jsonBody: body)).body);

  Uri _uri(String path, Map<String, String>? query) =>
      Uri.parse('$baseUrl/api/v4$path').replace(queryParameters: query);

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? jsonBody,
  }) async {
    final uri = _uri(path, query);
    final request = http.Request(method, uri)
      ..headers['PRIVATE-TOKEN'] = token
      ..headers['Accept'] = 'application/json';
    if (jsonBody != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(jsonBody);
    }

    final http.Response response;
    try {
      final streamed = await client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on HandshakeException catch (e) {
      final rejected = takeRejectedCertificate?.call();
      if (rejected != null) throw rejected;
      throw RemoteUnreachable('Secure connection to ${uri.host} failed: ${e.message}');
    } on TimeoutException {
      throw RemoteUnreachable('${uri.host} did not answer within ${timeout.inSeconds} s.');
    } on http.ClientException catch (e) {
      throw RemoteUnreachable('Could not reach ${uri.host}: ${e.message}');
    } on SocketException catch (e) {
      throw RemoteUnreachable('Could not reach ${uri.host}: ${e.message}');
    } on HttpException catch (e) {
      throw RemoteUnreachable('Could not reach ${uri.host}: ${e.message}');
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) return response;
    if (status == 401) {
      throw RemoteAuthRejected(
        'GitLab rejected the token. Replace it in the vault settings.',
      );
    }
    if (status == 429 || status == 502 || status == 503 || status == 504) {
      throw RemoteUnreachable('${uri.host} answered $status; will retry later.');
    }
    throw GitLabApiException(status, _messageOf(response));
  }

  static String _messageOf(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['error'];
        if (message is String) return message;
        if (message != null) return message.toString();
      }
    } on FormatException {
      // Not JSON; fall through to the status line.
    }
    return 'HTTP ${response.statusCode}';
  }
}
