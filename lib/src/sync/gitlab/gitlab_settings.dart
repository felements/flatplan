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

  /// When the token expires, as reported by GitLab at connect time. Null
  /// when unknown (no expiry, or the token-info endpoint was unavailable).
  final DateTime? tokenExpiresAt;

  const GitLabSettings({
    required this.baseUrl,
    required this.projectId,
    required this.projectPath,
    required this.branch,
    this.folder = '',
    this.certFingerprint,
    this.tokenExpiresAt,
  });

  factory GitLabSettings.fromSettings(Map<String, dynamic> settings) =>
      GitLabSettings(
        baseUrl: settings['base_url'] as String,
        projectId: int.parse(settings['project_id'].toString()),
        projectPath: settings['project_path'] as String,
        branch: settings['branch'] as String,
        folder: settings['folder'] as String? ?? '',
        certFingerprint: settings['cert_fingerprint'] as String?,
        tokenExpiresAt: parseExpiry(settings['token_expires_at']),
      );

  /// A date-only value (`2026-12-31`) or a full timestamp; null otherwise.
  static DateTime? parseExpiry(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static String formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  Map<String, dynamic> toSettings() => {
    'base_url': baseUrl,
    'project_id': projectId,
    'project_path': projectPath,
    'branch': branch,
    'folder': folder,
    if (certFingerprint != null) 'cert_fingerprint': certFingerprint,
    if (tokenExpiresAt != null) 'token_expires_at': formatDate(tokenExpiresAt!),
  };

  GitLabSettings copyWith({
    String? folder,
    String? certFingerprint,
    DateTime? tokenExpiresAt,
  }) => GitLabSettings(
    baseUrl: baseUrl,
    projectId: projectId,
    projectPath: projectPath,
    branch: branch,
    folder: folder ?? this.folder,
    certFingerprint: certFingerprint ?? this.certFingerprint,
    tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
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
