// Patches the three version sites in pubspec.yaml at CI build time; the repo
// copy is never committed with these changes (git tags are the version source
// of truth — see docs/superpowers/specs/2026-07-20-release-pipeline-design.md).
// Usage: dart run ci/patch_version.dart <x.y.z> <build-number> [pubspec-path]
import 'dart:io';

String patchPubspec(String content, String version, int buildNumber) {
  final sites = <String, (RegExp, String)>{
    'version': (
      RegExp(r'^version: .+$', multiLine: true),
      'version: $version+$buildNumber',
    ),
    'msix_config.msix_version': (
      RegExp(r'^  msix_version: .+$', multiLine: true),
      '  msix_version: "$version.0"',
    ),
    'flutter_to_debian.version': (
      RegExp(r'^  version: .+$', multiLine: true),
      '  version: "$version"',
    ),
  };
  var result = content;
  sites.forEach((name, site) {
    final (pattern, replacement) = site;
    if (!pattern.hasMatch(result)) {
      throw FormatException('version site not found in pubspec: $name');
    }
    result = result.replaceFirst(pattern, replacement);
  });
  return result;
}

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
        'usage: dart run ci/patch_version.dart <x.y.z> <build-number> [pubspec-path]');
    exit(2);
  }
  final version = args[0];
  final buildNumber = int.parse(args[1]);
  final path = args.length > 2 ? args[2] : 'pubspec.yaml';
  final file = File(path);
  file.writeAsStringSync(patchPubspec(file.readAsStringSync(), version, buildNumber));
  stdout.writeln('patched $path: version=$version+$buildNumber msix=$version.0');
}
