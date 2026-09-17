import 'dart:convert';
import 'dart:io';

import 'package:flatplan/src/sync/gitlab/gitlab_api.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_http.dart';
import 'package:flutter_test/flutter_test.dart';

/// DER bytes of the first certificate in a PEM file.
List<int> derOf(String pem) {
  final base64Body = pem
      .split('\n')
      .where((l) => l.isNotEmpty && !l.startsWith('-----'))
      .join();
  return base64.decode(base64Body);
}

void main() {
  test('fingerprint is upper-case SHA-256 pairs joined by colons', () {
    final fp = certificateFingerprint(utf8.encode('x'));
    expect(fp, matches(RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$')));
  });

  group('against a self-signed server', () {
    late HttpServer server;
    late String fingerprint;

    setUp(() async {
      final pem = File('test/fixtures/self_signed.pem').readAsStringSync();
      fingerprint = certificateFingerprint(derOf(pem));
      final context = SecurityContext()
        ..useCertificateChain('test/fixtures/self_signed.pem')
        ..usePrivateKey('test/fixtures/self_signed.key');
      server = await HttpServer.bindSecure('localhost', 0, context);
      server.listen((req) {
        req.response
          ..headers.contentType = ContentType.json
          ..write('{"id": 1, "name": "x", "path_with_namespace": "g/x", "default_branch": "main", "empty_repo": false}')
          ..close();
      });
    });

    tearDown(() => server.close(force: true));

    test('an unpinned client is offered the certificate', () async {
      final pinned = buildGitLabClient(host: 'localhost');
      final api = GitLabApi(
        client: pinned.client,
        baseUrl: 'https://localhost:${server.port}',
        token: 't',
        takeRejectedCertificate: pinned.takeRejected,
      );
      await expectLater(
        api.project(1),
        throwsA(isA<CertificateRejected>()
            .having((e) => e.fingerprint, 'fingerprint', fingerprint)
            .having((e) => e.host, 'host', 'localhost')
            .having((e) => e.subject, 'subject', contains('localhost'))),
      );
      pinned.close();
    });

    test('a client pinned to the right fingerprint succeeds', () async {
      final pinned = buildGitLabClient(host: 'localhost', certFingerprint: fingerprint);
      final api = GitLabApi(
        client: pinned.client,
        baseUrl: 'https://localhost:${server.port}',
        token: 't',
        takeRejectedCertificate: pinned.takeRejected,
      );
      expect((await api.project(1)).id, 1);
      pinned.close();
    });

    test('a client pinned to another fingerprint is offered the certificate', () async {
      final pinned = buildGitLabClient(host: 'localhost', certFingerprint: 'AA:BB');
      final api = GitLabApi(
        client: pinned.client,
        baseUrl: 'https://localhost:${server.port}',
        token: 't',
        takeRejectedCertificate: pinned.takeRejected,
      );
      await expectLater(api.project(1), throwsA(isA<CertificateRejected>()));
      pinned.close();
    });
  });
}
