import '../../models/models.dart';
import '../remote_store.dart';
import 'gitlab_http.dart';
import 'gitlab_remote_store.dart';
import 'gitlab_settings.dart';

/// Builds a [GitLabRemoteStore] for a vault. Makes no request: bad
/// credentials surface at the first sync, so opening works offline.
Future<RemoteStore> gitLabStoreFactory(
  RemoteVaultLocation location,
  Map<String, String> secrets,
) async {
  final settings = GitLabSettings.fromSettings(location.settings);
  final token = secrets[GitLabSettings.secretName];
  if (token == null) {
    throw StateError('The GitLab vault has no token in secure storage.');
  }
  return GitLabRemoteStore(
    api: gitLabApiFor(settings: settings, token: token),
    settings: settings,
  );
}

void registerGitLabProvider(RemoteStoreRegistry registry) =>
    registry.register(GitLabSettings.kind, gitLabStoreFactory);
