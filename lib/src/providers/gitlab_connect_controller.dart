import 'dart:async';
import 'dart:developer' show log;

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

enum FolderCheckKind { checking, periodFiles, empty, missing, newRepository, error }

/// What the chosen folder holds on the remote, as the form shows it.
class FolderCheck {
  final FolderCheckKind kind;
  final int count;
  final String? message;

  /// First and last period file names (without `.yaml`), sorted; set for
  /// [FolderCheckKind.periodFiles] so a wrong path is caught before it is
  /// saved, when it is still cheap to fix.
  final String? first;
  final String? last;

  const FolderCheck.checking()
    : kind = FolderCheckKind.checking,
      count = 0,
      message = null,
      first = null,
      last = null;
  const FolderCheck.periodFiles(this.count, {required this.first, required this.last})
    : kind = FolderCheckKind.periodFiles,
      message = null;
  const FolderCheck.empty()
    : kind = FolderCheckKind.empty,
      count = 0,
      message = null,
      first = null,
      last = null;
  const FolderCheck.missing()
    : kind = FolderCheckKind.missing,
      count = 0,
      message = null,
      first = null,
      last = null;
  const FolderCheck.newRepository()
    : kind = FolderCheckKind.newRepository,
      count = 0,
      message = null,
      first = null,
      last = null;
  const FolderCheck.error(this.message)
    : kind = FolderCheckKind.error,
      count = 0,
      first = null,
      last = null;

  String describe() => switch (kind) {
    FolderCheckKind.checking => 'Checking folder…',
    FolderCheckKind.periodFiles =>
      '$count period ${count == 1 ? 'file' : 'files'} found',
    FolderCheckKind.empty =>
      'No period files here yet, they will be created on first sync',
    FolderCheckKind.missing => 'Folder not found, it will be created on first sync',
    FolderCheckKind.newRepository =>
      'New repository, the branch will be created on first sync',
    FolderCheckKind.error => message ?? 'Could not read the folder',
  };

  /// "first … last" for found period files, the one name when there is a
  /// single file, null otherwise.
  String? get detail {
    final a = first;
    final b = last;
    if (a == null || b == null) return null;
    return a == b ? a : '$a … $b';
  }
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

  /// Expiry of the verified token, read at connect time. Kept in the vault
  /// settings so the vault list can warn before it runs out.
  DateTime? tokenExpiresAt;
  ConnectStep step = ConnectStep.token;
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

  /// One download per project for the life of the connection; a failure
  /// resolves to null so a missing picture never shows as an error.
  final Map<int, Future<Uint8List?>> _avatars = {};
  Timer? _searchTimer;
  Completer<void>? _searchCompleter;
  int _searchSeq = 0;
  String? _pendingToken;
  int _inFlight = 0;
  bool _disposed = false;

  /// True while any `_run`-driven action is in flight, even when several
  /// overlap (e.g. a debounced search finishing while a slower selection
  /// is still awaiting the network).
  bool get busy => _inFlight > 0;

  GitLabConnectController({required this.apiFactory, GitLabSettings? existing}) {
    if (existing != null) {
      selfHosted = !existing.isGitLabCom;
      baseUrl = existing.baseUrl;
      certFingerprint = existing.certFingerprint;
      tokenExpiresAt = existing.tokenExpiresAt;
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
    _serverChanged();
    _notify();
  }

  void setBaseUrl(String raw) {
    baseUrl = GitLabSettings.normalizeBaseUrl(raw);
    _serverChanged();
    _notify();
  }

  /// A pinned fingerprint and an open trust offer both belong to one host,
  /// so pointing the form at another server drops them unconditionally --
  /// even before anything was verified, where [_resetConnectionIfAdvanced]
  /// returns early. Otherwise a vault could be saved with the fingerprint
  /// of a host it never talked to.
  void _serverChanged() {
    certFingerprint = null;
    pendingCertificate = null;
    _resetConnectionIfAdvanced();
  }

  /// Changing which server the form points at must never leave `project`,
  /// `branch` or `token` verified against the *previous* server: without
  /// this, `canSave` would stay true and a save could combine the new
  /// `baseUrl` with the old host's project id/path and token. A no-op
  /// while still at the token step with nothing verified yet, so typing
  /// the url before the first connect stays quiet.
  void _resetConnectionIfAdvanced() {
    if (step == ConnectStep.token && token == null) return;
    token = null;
    _api = null;
    _avatars.clear();
    // A search still in flight belongs to the dropped connection.
    _searchSeq++;
    projects = const [];
    project = null;
    branches = const [];
    branch = null;
    folderCheck = null;
    suggestedName = null;
    connectError = null;
    pendingCertificate = null;
    step = ConnectStep.token;
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
  /// or cannot read tokens at all (403); both continue. Any other failure
  /// -- an old instance without the endpoint, a 5xx, a server that cannot
  /// be reached for this one call -- is inconclusive rather than proof of
  /// a bad token, so it continues too and the real work reports the
  /// problem if it persists.
  Future<bool> _legacyScopeOk(GitLabApi api) async {
    try {
      final info = await api.tokenInfo();
      tokenExpiresAt = info.expiresAt;
      return info.isFineGrained || info.scopes.contains('api');
    } on GitLabApiException {
      return true;
    } on RemoteUnreachable {
      return true;
    }
  }

  Future<void> trustCertificate() async {
    final offer = pendingCertificate;
    final candidate = _pendingToken;
    if (offer == null || candidate == null) return;
    if (offer.host != Uri.tryParse(baseUrl)?.host) {
      // The form moved to another server while the offer was in flight:
      // that fingerprint says nothing about the host now configured.
      pendingCertificate = null;
      _notify();
      return;
    }
    certFingerprint = offer.fingerprint;
    pendingCertificate = null;
    _notify();
    if (step == ConnectStep.target) {
      await verifyReplacementToken(candidate);
    } else {
      await connect(candidate);
    }
  }

  void dismissCertificate() {
    pendingCertificate = null;
    _notify();
  }

  /// Debounced by [searchDebounce]. A call superseded before its timer
  /// fires completes immediately (with no request sent) so its caller
  /// never hangs waiting on a query that was replaced. A call superseded
  /// *after* its timer fired but while its network call is still in
  /// flight is left to finish, but [_searchSeq] stops its stale answer
  /// from overwriting [projects] once a newer search has taken over.
  Future<void> search(String query) {
    _searchTimer?.cancel();
    final previous = _searchCompleter;
    if (previous != null && !previous.isCompleted) previous.complete();
    final completer = Completer<void>();
    _searchCompleter = completer;
    final seq = ++_searchSeq;
    _searchTimer = Timer(searchDebounce, () async {
      await _run(() async {
        final api = _api;
        if (api == null) return;
        final found = await api.searchProjects(query);
        if (seq != _searchSeq) return;
        projects = found;
        if (projects.isEmpty && query.contains('/')) {
          try {
            final byPath = await api.projectByPath(query.trim());
            if (seq != _searchSeq) return;
            projects = [byPath];
          } on GitLabApiException catch (e) {
            if (e.status != 404) rethrow;
          }
        }
      });
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  /// The project's avatar for its list row. No request for a project
  /// without one, and never an error: null means "show the initial".
  Future<Uint8List?> avatarFor(ProjectSummary project) {
    final api = _api;
    if (project.avatarUrl == null || api == null) return Future.value(null);
    return _avatars.putIfAbsent(
      project.id,
      () => api.projectAvatar(project.id).catchError((Object e) {
        log('Avatar of ${project.pathWithNamespace} not loaded: $e', name: 'flatplan.gitlab');
        return null;
      }),
    );
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

  /// One step back. From the location step the project stays chosen and
  /// the list reappears; from the repository step the connection is
  /// dropped so the token step ends with Connect again, which keeps every
  /// step ending in one explicit action. A no-op on the token step.
  void back() {
    switch (step) {
      case ConnectStep.target:
        step = ConnectStep.project;
        folderCheck = null;
      case ConnectStep.project:
        _resetConnectionIfAdvanced();
      case ConnectStep.server || ConnectStep.token:
        return;
    }
    _notify();
  }

  void selectBranch(String name) {
    branch = name;
    _notify();
    final api = _api;
    if (api != null) unawaited(_run(() => _checkFolder(api)));
  }

  /// Keeps [folder] in step with the field on every keystroke, so a save
  /// can never carry a value the user has already replaced. No request and
  /// no notification: the remote check waits for [setFolder].
  void updateFolder(String raw) {
    folder = GitLabSettings.normalizeFolder(raw);
  }

  /// Commits the field and checks the folder on the remote.
  Future<void> setFolder(String raw) => _run(() async {
    updateFolder(raw);
    final api = _api;
    if (api != null) await _checkFolder(api);
  });

  Future<void> _checkFolder(GitLabApi api) async {
    final chosen = project;
    final ref = branch;
    if (chosen == null || ref == null) return;
    folderCheck = const FolderCheck.checking();
    _notify();
    try {
      final entries = await api.tree(chosen.id, ref, folder);
      // Back may have left the location step meanwhile; its result would
      // then describe a folder nobody is looking at.
      if (step != ConnectStep.target) return;
      final prefix = folder.isEmpty ? '' : '$folder/';
      final periods = entries
          .where(
            (e) =>
                e.isBlob &&
                e.path == '$prefix${e.name}' &&
                e.name.endsWith('.yaml') &&
                !e.name.contains('.conflict-'),
          )
          .map((e) => e.name.substring(0, e.name.length - '.yaml'.length))
          .toList()
        ..sort();
      folderCheck = periods.isEmpty
          ? const FolderCheck.empty()
          : FolderCheck.periodFiles(periods.length, first: periods.first, last: periods.last);
    } on GitLabApiException catch (e) {
      if (step != ConnectStep.target) return;
      if (e.status == 404) {
        final fresh = await api.project(chosen.id);
        if (step != ConnectStep.target) return;
        folderCheck = fresh.emptyRepo ? const FolderCheck.newRepository() : const FolderCheck.missing();
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

  /// Edit form: reaches the server with the stored token so a changed
  /// certificate is offered again. The pin changes only on
  /// [trustCertificate].
  Future<void> fetchCurrentCertificate(String storedToken) {
    _pendingToken = storedToken;
    return _run(() async {
      final api = apiFactory(settings: _probeSettings(), token: storedToken);
      await api.searchProjects('');
      _api = api;
      token = storedToken;
    });
  }

  bool get canSave =>
      token != null && project != null && branch != null && step == ConnectStep.target;

  GitLabSettings toSettings() => GitLabSettings(
    baseUrl: baseUrl,
    projectId: project!.id,
    projectPath: project!.pathWithNamespace,
    branch: branch!,
    folder: folder,
    certFingerprint: certFingerprint,
    tokenExpiresAt: tokenExpiresAt,
  );

  /// Runs one wizard action: tracks [busy] (reentrant-safe via a counter,
  /// since a debounced search may finish while a slower action is still in
  /// flight), maps every failure to [connectError] or [pendingCertificate],
  /// and notifies. Never touches the widget tree once disposed; an action
  /// already in flight when disposal happens is left to finish (its state
  /// mutations are harmless once nothing is listening), but no new one
  /// starts once [_disposed].
  Future<void> _run(Future<void> Function() action) async {
    if (_disposed) return;
    _inFlight++;
    _notify();
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
    } catch (e) {
      // Fire-and-forget callers (a debounced search, a branch selection)
      // never await this future, so an untyped failure would otherwise
      // vanish and leave the form looking idle and fine.
      connectError = 'Unexpected error: $e';
    } finally {
      _inFlight--;
      // A plain call is fine in `finally` (only return/break/continue trip
      // the control_flow_in_finally lint); this guarantees every listener
      // sees `busy` fall back to false.
      _notify();
    }
  }

  /// [notifyListeners] guarded against firing once disposed: a debounced
  /// search's timer callback, or an action it started, can still resolve
  /// after the widget that owns this controller has torn it down.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    // The cancelled timer will never fire, so nothing else would ever
    // complete a search awaited by the caller that started it.
    final pending = _searchCompleter;
    if (pending != null && !pending.isCompleted) pending.complete();
    _searchCompleter = null;
    super.dispose();
  }
}
