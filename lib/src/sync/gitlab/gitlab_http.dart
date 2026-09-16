import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'gitlab_api.dart';
import 'gitlab_settings.dart';

/// SHA-256 of a certificate's DER bytes as `AB:CD:…`, the form shown to
/// the user and stored in the vault settings.
String certificateFingerprint(List<int> der) {
  final hex = sha256.convert(der).toString().toUpperCase();
  final pairs = <String>[];
  for (var i = 0; i < hex.length; i += 2) {
    pairs.add(hex.substring(i, i + 2));
  }
  return pairs.join(':');
}

/// An HTTP client that trusts at most one extra certificate, identified
/// by fingerprint, for one host. Any other untrusted certificate is
/// recorded so the caller can offer it to the user.
class PinnedClient {
  final http.Client client;
  final HttpClient _io;
  CertificateRejected? _rejected;

  PinnedClient._(this.client, this._io);

  /// The certificate rejected by the last failed handshake, if any. Clears
  /// it, so a later success does not report a stale offer.
  CertificateRejected? takeRejected() {
    final value = _rejected;
    _rejected = null;
    return value;
  }

  void close() {
    client.close();
    _io.close(force: true);
  }
}

PinnedClient buildGitLabClient({
  required String host,
  String? certFingerprint,
  Duration timeout = const Duration(seconds: 30),
}) {
  final io = HttpClient()..connectionTimeout = timeout;
  late final PinnedClient pinned;
  io.badCertificateCallback = (X509Certificate cert, String requestHost, int port) {
    final fingerprint = certificateFingerprint(cert.der);
    if (requestHost == host && certFingerprint != null && fingerprint == certFingerprint) {
      return true;
    }
    pinned._rejected = CertificateRejected(
      host: requestHost,
      subject: cert.subject,
      fingerprint: fingerprint,
    );
    return false;
  };
  pinned = PinnedClient._(IOClient(io), io);
  return pinned;
}

/// The API client production code uses for a vault. Tests pass [client]
/// to skip the real network.
GitLabApi gitLabApiFor({
  required GitLabSettings settings,
  required String token,
  http.Client? client,
}) {
  if (client != null) {
    return GitLabApi(client: client, baseUrl: settings.baseUrl, token: token);
  }
  final pinned = buildGitLabClient(
    host: settings.host,
    certFingerprint: settings.certFingerprint,
  );
  return GitLabApi(
    client: pinned.client,
    baseUrl: settings.baseUrl,
    token: token,
    takeRejectedCertificate: pinned.takeRejected,
  );
}
