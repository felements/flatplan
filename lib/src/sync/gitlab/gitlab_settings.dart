/// Typed view over a GitLab vault's non-secret settings map. The store, the
/// form and the location line go through this and never read raw keys.
class GitLabSettings {
  static const kind = 'gitlab';
  static const secretName = 'token';
  static const gitLabCom = 'https://gitlab.com';

  final String baseUrl;
  final int projectId;
  final String projectPath;
  final String branch;
  final String folder;
  final String? certFingerprint;

  const GitLabSettings({
    required this.baseUrl,
    required this.projectId,
    required this.projectPath,
    required this.branch,
    this.folder = '',
    this.certFingerprint,
  });

  factory GitLabSettings.fromSettings(Map<String, dynamic> settings) =>
      GitLabSettings(
        baseUrl: settings['base_url'] as String,
        projectId: int.parse(settings['project_id'].toString()),
        projectPath: settings['project_path'] as String,
        branch: settings['branch'] as String,
        folder: settings['folder'] as String? ?? '',
        certFingerprint: settings['cert_fingerprint'] as String?,
      );

  Map<String, dynamic> toSettings() => {
    'base_url': baseUrl,
    'project_id': projectId,
    'project_path': projectPath,
    'branch': branch,
    'folder': folder,
    if (certFingerprint != null) 'cert_fingerprint': certFingerprint,
  };

  GitLabSettings copyWith({String? folder, String? certFingerprint}) =>
      GitLabSettings(
        baseUrl: baseUrl,
        projectId: projectId,
        projectPath: projectPath,
        branch: branch,
        folder: folder ?? this.folder,
        certFingerprint: certFingerprint ?? this.certFingerprint,
      );

  String get host => Uri.parse(baseUrl).host;

  bool get isGitLabCom => host == 'gitlab.com';

  String get locationLine {
    final where = isGitLabCom ? 'GitLab' : host;
    final path = folder.isEmpty ? projectPath : '$projectPath/$folder';
    return '$where · $path';
  }

  String pathOf(String name) => folder.isEmpty ? name : '$folder/$name';

  static String normalizeBaseUrl(String raw) {
    var value = raw.trim().replaceAll(RegExp(r'/+$'), '');
    if (!value.contains('://')) value = 'https://$value';
    return value;
  }

  static String normalizeFolder(String raw) =>
      raw.trim().replaceAll(RegExp(r'^/+|/+$'), '');
}
