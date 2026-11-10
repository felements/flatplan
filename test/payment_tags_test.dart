import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/payment_tags.dart';
import 'package:flatplan/src/models/models.dart';

FactExpense _fact(String id, double amount, [String? description]) =>
    FactExpense(
      id: id,
      amount: amount,
      description: description,
      timestamp: DateTime(2026, 1, 2),
    );

Period _period(String id, List<Category> categories) => Period(
  id: id,
  name: id,
  startDate: DateTime(2026, 1, 1),
  baseCurrency: 'EUR',
  lastModified: DateTime(2026, 1, 1),
  categories: categories,
);

Category _spending(
  String id,
  List<FactExpense> facts, {
  CategoryType type = CategoryType.optionalExpense,
}) => Category(id: id, name: id, type: type, factExpenses: facts);

void main() {
  group('splitTags', () {
    test('moves trailing tags out of the text', () {
      final result = splitTags('something in alza #tws #renovation');
      expect(result.text, 'something in alza');
      expect(result.tags, ['tws', 'renovation']);
    });

    test('cuts a tag out of the middle and keeps the text around it', () {
      final result = splitTags('tiles #renovation for the bathroom');
      expect(result.text, 'tiles for the bathroom');
      expect(result.tags, ['renovation']);
    });

    test('keeps the order the tags were written in', () {
      final result = splitTags('#b paint #a #c');
      expect(result.tags, ['b', 'a', 'c']);
      expect(result.text, 'paint');
    });

    test('a comment of only tags leaves empty text', () {
      final result = splitTags('#renovation #tws');
      expect(result.text, '');
      expect(result.tags, ['renovation', 'tws']);
    });

    test('lowercases tags and drops case-insensitive repeats', () {
      final result = splitTags('paint #Renovation #renovation #RENOVATION');
      expect(result.tags, ['renovation']);
    });

    test('accepts letters of any language, digits, dash and underscore', () {
      final result = splitTags('#ремонт #koupelna_2 #re-do');
      expect(result.tags, ['ремонт', 'koupelna_2', 're-do']);
    });

    test('a number-only hashtag is an order number, not a tag', () {
      final result = splitTags('order #12345 #renovation');
      expect(result.text, 'order #12345');
      expect(result.tags, ['renovation']);
    });

    test('a hash inside a word is not a tag', () {
      final result = splitTags('learning C# and F#x');
      expect(result.text, 'learning C# and F#x');
      expect(result.tags, isEmpty);
    });

    test('punctuation after a removed tag sticks to the preceding word', () {
      final result = splitTags('tiles #renovation, grout #tws.');
      expect(result.text, 'tiles, grout.');
      expect(result.tags, ['renovation', 'tws']);
    });

    test('a separator left at the start by a removed tag is dropped', () {
      final result = splitTags('#renovation, tiles');
      expect(result.text, 'tiles');
    });

    test('text without tags comes back untouched', () {
      final result = splitTags('bread  ,  milk');
      expect(result.text, 'bread  ,  milk');
      expect(result.tags, isEmpty);
    });

    test('null and empty comments have no tags', () {
      expect(splitTags(null).tags, isEmpty);
      expect(splitTags(null).text, '');
      expect(splitTags('').tags, isEmpty);
    });
  });

  group('topTags', () {
    test('sums the full amount of a payment under every one of its tags', () {
      final period = _period('p', [
        _spending('home', [
          _fact('a', 100, 'tiles #renovation #tws'),
          _fact('b', 30, 'paint #renovation'),
        ]),
      ]);

      final result = topTags(period: period, allPeriods: [period]);

      expect(result.map((t) => t.tag), ['renovation', 'tws']);
      expect(result[0].periodTotal, 130);
      expect(result[1].periodTotal, 100);
    });

    test('a tag repeated in one comment counts the payment once', () {
      final period = _period('p', [
        _spending('home', [_fact('a', 100, 'hosting #tws #TWS #tws')]),
      ]);

      final tags = topTags(period: period, allPeriods: [period]);

      expect(tags.single.tag, 'tws');
      expect(tags.single.periodTotal, 100);
      expect(tags.single.allPeriodsTotal, 100);
    });

    test('adds every period into the all-periods total', () {
      final older = _period('older', [
        _spending('home', [_fact('o1', 500, '#renovation')]),
      ]);
      final current = _period('current', [
        _spending('home', [_fact('c1', 40, '#renovation')]),
      ]);

      final result = topTags(period: current, allPeriods: [current, older]);

      expect(result.single.periodTotal, 40);
      expect(result.single.allPeriodsTotal, 540);
    });

    test('uses the given period rather than a stale copy in the list', () {
      final stale = _period('current', [
        _spending('home', [_fact('c1', 40, '#renovation')]),
      ]);
      final fresh = _period('current', [
        _spending('home', [
          _fact('c1', 40, '#renovation'),
          _fact('c2', 60, '#renovation'),
        ]),
      ]);

      final result = topTags(period: fresh, allPeriods: [stale]);

      expect(result.single.periodTotal, 100);
      expect(result.single.allPeriodsTotal, 100);
    });

    test('matches a tag across periods regardless of case', () {
      final older = _period('older', [
        _spending('home', [_fact('o1', 10, '#Renovation')]),
      ]);
      final current = _period('current', [
        _spending('home', [_fact('c1', 5, '#renovation')]),
      ]);

      final result = topTags(period: current, allPeriods: [older, current]);

      expect(result.single.allPeriodsTotal, 15);
    });

    test('lists only tags spent on in the given period', () {
      final older = _period('older', [
        _spending('home', [_fact('o1', 900, '#holiday')]),
      ]);
      final current = _period('current', [
        _spending('home', [_fact('c1', 5, '#renovation')]),
      ]);

      final result = topTags(period: current, allPeriods: [older, current]);

      expect(result.map((t) => t.tag), ['renovation']);
    });

    test('ignores tagged income', () {
      final period = _period('p', [
        _spending('salary', [
          _fact('s1', 3000, '#renovation'),
        ], type: CategoryType.income),
        _spending('home', [_fact('h1', 20, '#renovation')]),
      ]);

      final result = topTags(period: period, allPeriods: [period]);

      expect(result.single.periodTotal, 20);
      expect(result.single.allPeriodsTotal, 20);
    });

    test('ranks by period total and keeps only the top ones', () {
      final period = _period('p', [
        _spending('home', [
          for (var i = 1; i <= 7; i++) _fact('f$i', i * 10.0, '#t$i'),
        ]),
      ]);

      final result = topTags(period: period, allPeriods: [period], limit: 5);

      expect(result.map((t) => t.tag), ['t7', 't6', 't5', 't4', 't3']);
    });

    test('a period without tags has no top tags', () {
      final period = _period('p', [
        _spending('home', [_fact('a', 10, 'bread'), _fact('b', 5)]),
      ]);

      expect(topTags(period: period, allPeriods: [period]), isEmpty);
    });
  });
}
