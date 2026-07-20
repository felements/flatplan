import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../ci/patch_version.dart';

const sample = '''
version: 1.0.2+3

dependencies:
  flutter:
    sdk: flutter

msix_config:
  display_name: "flatplan"
  msix_version: "1.0.2.0"
  install_certificate: false

flutter_to_debian:
  name: "flatplan"
  version: "1.0.2"
  maintainer: "felements"
''';

void main() {
  test('patches all three version sites', () {
    final lines = patchPubspec(sample, '2.3.4', 57).split('\n');
    expect(lines, contains('version: 2.3.4+57'));
    expect(lines, contains('  msix_version: "2.3.4.0"'));
    expect(lines, contains('  version: "2.3.4"'));
  });

  test('leaves unrelated lines untouched', () {
    final out = patchPubspec(sample, '2.3.4', 57);
    expect(out, contains('  display_name: "flatplan"'));
    expect(out, contains('  maintainer: "felements"'));
  });

  test('throws when a version site is missing', () {
    expect(
      () => patchPubspec('name: flatplan\n', '2.3.4', 1),
      throwsFormatException,
    );
  });

  test('patches the real pubspec.yaml', () {
    final real = File('pubspec.yaml').readAsStringSync();
    final lines = patchPubspec(real, '9.9.9', 42).split('\n');
    expect(lines, contains('version: 9.9.9+42'));
    expect(lines, contains('  msix_version: "9.9.9.0"'));
    expect(lines, contains('  version: "9.9.9"'));
  });
}
