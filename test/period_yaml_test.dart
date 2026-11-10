import 'package:flutter_test/flutter_test.dart';
import 'package:json2yaml/json2yaml.dart';
import 'package:yaml/yaml.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/period_yaml.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';

/// Reads [yaml] back into plain maps and lists for comparison.
dynamic _plain(dynamic node) {
  if (node is YamlMap) {
    return {for (final e in node.entries) e.key.toString(): _plain(e.value)};
  }
  if (node is YamlList) return [for (final e in node) _plain(e)];
  return node;
}

void main() {
  group('encodePeriodYaml', () {
    test('writes values the library already handles exactly as before', () {
      final map = <String, dynamic>{
        'amount': 12.5,
        'base_currency': 'EUR',
        'categories': [
          {
            'description': 'tiles for the bathroom #renovation',
            'name': 'Home: repairs',
            'tags': ['a', 'b'],
          },
        ],
        'name': 'November 2026',
        'start_date': '2026-11-01T00:00:00.000',
      };

      expect(
        encodePeriodYaml(map),
        json2yaml(map, yamlStyle: YamlStyle.generic),
      );
    });

    for (final value in [
      '#renovation',
      '#renovation tiles',
      'say "hi", ok',
      r'C:\path, here',
      '- dash first',
      '"quoted"',
      "'single'",
      'TRUE',
      'null',
      '~',
      '',
      ' leading space',
      'trailing colon:',
      'first\n\nthird',
      'tab\there',
      'C# rocks',
      '0o17',
      '.inf',
      'line\u2028separator',
    ]) {
      test(
        'a string reads back unchanged: ${value.replaceAll('\n', r'\n')}',
        () {
          final map = <String, dynamic>{
            'description': value,
            'items': [value],
          };

          final decoded = _plain(loadYaml(encodePeriodYaml(map)));

          expect(decoded, map);
        },
      );
    }
  });

  test(
    'a payment comment starting with a tag survives save and load',
    () async {
      final repo = PeriodRepository(workspace: MemoryWorkspace());
      await repo.savePeriod(
        Period(
          id: 'p',
          name: 'p',
          startDate: DateTime(2026, 1, 1),
          baseCurrency: 'EUR',
          lastModified: DateTime(2026, 1, 1),
          categories: [
            Category(
              id: 'c',
              name: 'c',
              factExpenses: [
                FactExpense(
                  id: 'f',
                  amount: 1,
                  description: '#renovation tiles',
                  timestamp: DateTime(2026, 1, 2),
                ),
              ],
            ),
          ],
        ),
      );

      final loaded = await repo.loadAll();

      expect(loaded.failures, isEmpty);
      expect(
        loaded.periods.single.categories.single.factExpenses.single.description,
        '#renovation tiles',
      );
    },
  );
}
