import 'package:flatplan/src/sync/gitlab/gitlab_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const full = GitLabSettings(
    baseUrl: 'https://gitlab.example.com',
    projectId: 42,
    projectPath: 'group/repo',
    branch: 'main',
    folder: 'budget',
    certFingerprint: 'AB:CD',
  );

  test('round-trips through the settings map with snake_case keys', () {
    final map = full.toSettings();
    expect(map, {
      'base_url': 'https://gitlab.example.com',
      'project_id': 42,
      'project_path': 'group/repo',
      'branch': 'main',
      'folder': 'budget',
      'cert_fingerprint': 'AB:CD',
    });
    final back = GitLabSettings.fromSettings(map);
    expect(back.toSettings(), map);
  });

  test('omits the fingerprint key when unset and accepts a string project id', () {
    final s = GitLabSettings.fromSettings({
      'base_url': 'https://gitlab.com',
      'project_id': '7',
      'project_path': 'me/budget',
      'branch': 'main',
    });
    expect(s.projectId, 7);
    expect(s.folder, '');
    expect(s.certFingerprint, isNull);
    expect(s.toSettings().containsKey('cert_fingerprint'), isFalse);
  });

  test('location line names GitLab for gitlab.com and the host otherwise', () {
    expect(full.locationLine, 'gitlab.example.com · group/repo/budget');
    final com = GitLabSettings(
      baseUrl: GitLabSettings.gitLabCom,
      projectId: 1,
      projectPath: 'me/budget',
      branch: 'main',
    );
    expect(com.isGitLabCom, isTrue);
    expect(com.locationLine, 'GitLab · me/budget');
  });

  test('pathOf joins the folder only when set', () {
    expect(full.pathOf('a.yaml'), 'budget/a.yaml');
    expect(full.copyWith(folder: '').pathOf('a.yaml'), 'a.yaml');
  });

  test('normalisers strip slashes and add a scheme', () {
    expect(GitLabSettings.normalizeBaseUrl(' gitlab.example.com/ '), 'https://gitlab.example.com');
    expect(GitLabSettings.normalizeBaseUrl('http://10.0.0.5:8080//'), 'http://10.0.0.5:8080');
    expect(GitLabSettings.normalizeFolder(' /budget/2026/ '), 'budget/2026');
    expect(GitLabSettings.normalizeFolder('/'), '');
  });
}
