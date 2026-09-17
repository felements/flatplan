import 'package:flatplan/src/sync/gitlab/git_blob.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty content hashes to the empty git blob', () {
    expect(gitBlobSha(''), 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391');
  });

  test('matches git hash-object for ASCII content', () {
    expect(gitBlobSha('hello\n'), 'ce013625030ba8dba906f756967f9e9ca394464a');
  });

  test('uses the UTF-8 byte length, not the code-unit length', () {
    expect(gitBlobSha('Größe: 5 €\n'), '172dbb623ac2f4951918c960d75321a87fb78e9e');
  });
}
