import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../sync/gitlab/gitlab_api.dart';
import '../sync/gitlab/gitlab_http.dart';
import '../sync/gitlab/gitlab_settings.dart';
import '../sync/remote_store.dart';

part 'gitlab_connect_controller.g.dart';

typedef GitLabApiFactory =
    GitLabApi Function({required GitLabSettings settings, required String token});

/// How the connect flow builds an API client. Tests override this with a
/// factory over a `MockClient`.
@Riverpod(keepAlive: true)
GitLabApiFactory gitLabApiFactory(Ref ref) =>
    ({required settings, required token}) =>
        gitLabApiFor(settings: settings, token: token);

enum ConnectStep { server, token, project, target }

enum FolderCheckKind { periodFiles, empty, newRepository, error }

class FolderCheck {
  final FolderCheckKind kind;
  final int count;
  final String? message;

  const FolderCheck.periodFiles(this.count)
    : kind = FolderCheckKind.periodFiles,
      message = null;
  const FolderCheck.empty() : kind = FolderCheckKind.empty, count = 0, message = null;
  const FolderCheck.newRepository()
    : kind = FolderCheckKind.newRepository,
      count = 0,
      message = null;
  const FolderCheck.error(this.message) : kind = FolderCheckKind.error, count = 0;

  String describe() => switch (kind) {
    FolderCheckKind.periodFiles =>
      '$count period ${count == 1 ? 'file' : 'files'} found',
    FolderCheckKind.empty => 'Empty, files will be created on first sync',
    FolderCheckKind.newRepository =>
      'New repository, the branch will be created on first sync',
    FolderCheckKind.error => message ?? 'Could not read the folder',
  };
}

/// Drives the GitLab connect wizard: server, token, project, branch and
/// folder. Owns the API client during setup so the form only renders.
class GitLabConnectController extends ChangeNotifier {
  static const searchDebounce = Duration(milliseconds: 300);
  static const legacyScopeError =
      'This legacy token needs the "api" scope. Create a new token with '
      'that scope, or a fine-grained token with the permissions listed below.';

  final GitLabApiFactory apiFactory;

  bool selfHosted = false;
  String baseUrl = GitLabSettings.gitLabCom;
  String? certFingerprint;
  ConnectStep step = ConnectStep.token;
  bool busy = false;
  String? connectError;
  CertificateRejected? pendingCertificate;

  /// Verified token, kept only until the form saves it to secure storage.
  String? token;

  List<ProjectSummary> projects = const [];
  ProjectSummary? project;
  List<String> branches = const [];
  String? branch;
  String folder = 'budget';
  FolderCheck? folderCheck;
  String? suggestedName;

  GitLabApi? _api;
  Timer? _searchTimer;
  String? _pendingToken;

  GitLabConnectController({required this.apiFactory, GitLabSettings? existing}) {
    if (existing != null) {
      selfHosted = !existing.isGitLabCom;
      baseUrl = existing.baseUrl;
      certFingerprint = existing.certFingerprint;
      project = ProjectSummary(
        id: existing.projectId,
        name: existing.projectPath.split('/').last,
        pathWithNamespace: existing.projectPath,
        defaultBranch: existing.branch,
        emptyRepo: false,
      );
      branch = existing.branch;
      branches = [existing.branch];
      folder = existing.folder;
      step = ConnectStep.target;
    }
  }

  void setSelfHosted(bool value) {
    selfHosted = value;
    if (!value) baseUrl = GitLabSettings.gitLabCom;
    notifyListeners();
  }

  void setBaseUrl(String raw) {
    baseUrl = GitLabSettings.normalizeBaseUrl(raw);
    notifyListeners();
  }

  GitLabSettings _probeSettings() => GitLabSettings(
    baseUrl: baseUrl,
    projectId: project?.id ?? 0,
    projectPath: project?.pathWithNamespace ?? '',
    branch: branch ?? 'main',
    folder: folder,
    certFingerprint: certFingerprint,
  );

  Future<void> connect(String candidate) => _run(() async {
    _pendingToken = candidate;
    connectError = null;
    pendingCertificate = null;
    token = null;
    final api = apiFactory(settings: _probeSettings(), token: candidate);
    projects = await api.searchProjects('');
    if (!await _legacyScopeOk(api)) {
      connectError = legacyScopeError;
      return;
    }
    _api = api;
    token = candidate;
    step = ConnectStep.project;
  });

  /// Best effort: only a legacy token can answer, and only a legacy token
  /// can lack `api`. A fine-grained token either reports granular scopes
  /// or cannot read tokens at all (403); both continue.
  Future<bool> _legacyScopeOk(GitLabApi api) async {
    try {
      final info = await api.tokenInfo();
      return info.isFineGrained || info.scopes.contains('api');
    } on GitLabApiException catch (e) {
      if (e.status == 403 || e.status == 404) return true;
      rethrow;
    }
  }

  Future<void> trustCertificate() async {
    final offer = pendingCertificate;
    final candidate = _pendingToken;
    if (offer == null || candidate == null) return;
    certFingerprint = offer.fingerprint;
    pendingCertificate = null;
    notifyListeners();
    if (step == ConnectStep.target) {
      await verifyReplacementToken(candidate);
    } else {
      await connect(candidate);
    }
  }

  void dismissCertificate() {
    pendingCertificate = null;
    notifyListeners();
  }

  Future<void> search(String query) {
    _searchTimer?.cancel();
    final completer = Completer<void>();
    _searchTimer = Timer(searchDebounce, () async {
      await _run(() async {
        final api = _api;
        if (api == null) return;
        projects = await api.searchProjects(query);
        if (projects.isEmpty && query.contains('/')) {
          try {
            projects = [await api.projectByPath(query.trim())];
          } on GitLabApiException catch (e) {
            if (e.status != 404) rethrow;
          }
        }
      });
      completer.complete();
    });
    return completer.future;
  }

  Future<void> selectProject(ProjectSummary chosen) => _run(() async {
    final api = _api!;
    project = chosen;
    suggestedName = chosen.name;
    branches = await api.branches(chosen.id);
    if (branches.isEmpty) branches = [chosen.defaultBranch];
    branch = branches.contains(chosen.defaultBranch) ? chosen.defaultBranch : branches.first;
    step = ConnectStep.target;
    await _checkFolder(api);
  });

  void selectBranch(String name) {
    branch = name;
    notifyListeners();
    final api = _api;
    if (api != null) unawaited(_run(() => _checkFolder(api)));
  }

  Future<void> setFolder(String raw) => _run(() async {
    folder = GitLabSettings.normalizeFolder(raw);
    final api = _api;
    if (api != null) await _checkFolder(api);
  });

  Future<void> _checkFolder(GitLabApi api) async {
    final chosen = project;
    final ref = branch;
    if (chosen == null || ref == null) return;
    try {
      final entries = await api.tree(chosen.id, ref, folder);
      final prefix = folder.isEmpty ? '' : '$folder/';
      final periods = entries.where(
        (e) =>
            e.isBlob &&
            e.path == '$prefix${e.name}' &&
            e.name.endsWith('.yaml') &&
            !e.name.contains('.conflict-'),
      );
      folderCheck = periods.isEmpty ? const FolderCheck.empty() : FolderCheck.periodFiles(periods.length);
    } on GitLabApiException catch (e) {
      if (e.status == 404) {
        final fresh = await api.project(chosen.id);
        folderCheck = fresh.emptyRepo ? const FolderCheck.newRepository() : const FolderCheck.empty();
      } else {
        folderCheck = FolderCheck.error(e.message);
      }
    }
  }

  /// Edit form: proves [candidate] can read the stored project.
  Future<void> verifyReplacementToken(String candidate) => _run(() async {
    _pendingToken = candidate;
    connectError = null;
    pendingCertificate = null;
    token = null;
    final api = apiFactory(settings: _probeSettings(), token: candidate);
    await api.searchProjects('');
    if (!await _legacyScopeOk(api)) {
      connectError = legacyScopeError;
      return;
    }
    await api.project(project!.id);
    _api = api;
    token = candidate;
  });

  bool get canSave =>
      token != null && project != null && branch != null && step == ConnectStep.target;

  GitLabSettings toSettings() => GitLabSettings(
    baseUrl: baseUrl,
    projectId: project!.id,
    projectPath: project!.pathWithNamespace,
    branch: branch!,
    folder: folder,
    certFingerprint: certFingerprint,
  );

  /// Runs one wizard action: sets [busy], maps every failure to
  /// [connectError] or [pendingCertificate], and notifies.
  Future<void> _run(Future<void> Function() action) async {
    busy = true;
    notifyListeners();
    try {
      await action();
    } on CertificateRejected catch (e) {
      pendingCertificate = e;
    } on RemoteAuthRejected {
      connectError = 'GitLab rejected this token. Check it and try again.';
    } on RemoteUnreachable catch (e) {
      connectError = 'Could not reach $baseUrl. ${e.message}';
    } on GitLabApiException catch (e) {
      connectError = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}
