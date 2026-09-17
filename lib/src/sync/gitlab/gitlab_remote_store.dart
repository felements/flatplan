import '../remote_store.dart';
import 'git_blob.dart';
import 'gitlab_api.dart';
import 'gitlab_settings.dart';

/// A vault folder in a GitLab repository. Versions are git blob ids, so
/// identical content is never a conflict and a push can report new
/// versions without another request. Every push is one commit.
class GitLabRemoteStore implements RemoteStore {
  static const commitMessagePrefix = 'FlatPlan sync';

  final GitLabApi api;
  final GitLabSettings settings;

  GitLabRemoteStore({required this.api, required this.settings});

  static String commitMessage(int count) =>
      '$commitMessagePrefix: $count ${count == 1 ? 'file' : 'files'}';

  @override
  Future<Map<String, String>> listTree() async {
    final List<TreeEntry> entries;
    try {
      entries = await api.tree(settings.projectId, settings.branch, settings.folder);
    } on GitLabApiException catch (e) {
      if (e.status != 404) rethrow;
      // An empty answer makes the engine delete mirror files that are no
      // longer on the remote, so find out what is actually missing first.
      final project = await api.project(settings.projectId);
      if (project.emptyRepo) return const {};
      if (await api.branchExists(settings.projectId, settings.branch)) {
        return const {}; // the folder does not exist yet
      }
      throw GitLabApiException(
        404,
        "Branch '${settings.branch}' was not found in ${settings.projectPath}.",
      );
    }
    final prefix = settings.folder.isEmpty ? '' : '${settings.folder}/';
    return {
      for (final e in entries)
        if (e.isBlob && e.path == '$prefix${e.name}') e.name: e.id,
    };
  }

  @override
  Future<RemoteFile> read(String name) async {
    final file = await api.rawFile(settings.projectId, settings.branch, settings.pathOf(name));
    return RemoteFile(content: file.content, version: file.blobId);
  }

  @override
  Future<Map<String, String>> writeBatch(List<RemoteChange> changes) async {
    final current = await listTree();

    final stale = <String>[];
    for (final change in changes) {
      final live = current[change.name];
      switch (change) {
        case RemotePut(:final expectedVersion):
          if (expectedVersion == null ? live != null : live != expectedVersion) {
            stale.add(change.name);
          }
        case RemoteDelete(:final expectedVersion):
          if (live != expectedVersion) stale.add(change.name);
      }
    }
    if (stale.isNotEmpty) throw RemoteConflict(stale);

    final versions = <String, String>{};
    final actions = <CommitAction>[];
    for (final change in changes) {
      switch (change) {
        case RemotePut(:final name, :final content, :final expectedVersion):
          final sha = gitBlobSha(content);
          versions[name] = sha;
          if (sha == expectedVersion) continue; // already on the remote
          actions.add(CommitAction(
            action: expectedVersion == null ? 'create' : 'update',
            filePath: settings.pathOf(name),
            content: content,
          ));
        case RemoteDelete(:final name):
          actions.add(CommitAction(action: 'delete', filePath: settings.pathOf(name)));
      }
    }
    if (actions.isEmpty) return versions;

    try {
      await api.commit(
        settings.projectId,
        settings.branch,
        commitMessage(actions.length),
        actions,
      );
    } on GitLabApiException catch (e) {
      if (e.status == 400 && _looksLikeRefusal(e.message)) {
        throw GitLabApiException(
          400,
          "GitLab refused the push to '${settings.branch}': ${e.message}. "
          'Use another branch or a token with the Maintainer role.',
        );
      }
      rethrow;
    }
    return versions;
  }

  static bool _looksLikeRefusal(String message) {
    final lower = message.toLowerCase();
    return lower.contains('protected') ||
        lower.contains('not allowed') ||
        lower.contains('permission');
  }
}
