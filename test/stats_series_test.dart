import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/period_extensions.dart';
import 'package:flatplan/src/logic/period_stats.dart';
import 'package:flatplan/src/logic/stats_series.dart';
import 'package:flatplan/src/models/models.dart';

import 'support/stats_fixtures.dart';

void main() {
  final today = DateTime(2026, 11, 10);

  List<Period> sepOctNovDec() => [
    period('oct', DateTime(2026, 10, 5), []),
    period('sep', DateTime(2026, 9, 5), []),
    period('nov', DateTime(2026, 11, 5), []),
    period('dec', DateTime(2026, 11, 11), []),
  ];

  group('chartPeriods', () {
    test('sorts by start date and drops periods starting after today', () {
      expect(chartPeriods(sepOctNovDec(), today: today).map((p) => p.id), [
        'sep',
        'oct',
        'nov',
      ]);
      expect(
        chartPeriods([
          period('t', DateTime(2026, 11, 10), []),
        ], today: today).map((p) => p.id),
        ['t'],
      );
    });

    test('compares calendar days, not the time of day', () {
      final late = period('late', DateTime(2026, 11, 10, 23, 59), []);
      final noon = DateTime(2026, 11, 10, 12);
      expect(chartPeriods([late], today: noon).map((p) => p.id), ['late']);
    });

    test('keeps periods whose start month is in the range, both ends '
        'included', () {
      final ps = sepOctNovDec();
      expect(
        chartPeriods(
          ps,
          today: today,
          range: MonthRange(DateTime(2026, 10), DateTime(2026, 11)),
        ).map((p) => p.id),
        ['oct', 'nov'],
      );
      expect(
        chartPeriods(
          ps,
          today: today,
          range: MonthRange(DateTime(2026, 12), DateTime(2026, 12)),
        ),
        isEmpty,
      );
    });

    test('a month range is stored as the first instant of each month', () {
      final range = MonthRange(
        DateTime(2026, 10, 17, 9),
        DateTime(2026, 11, 3),
      );
      expect(range.from, DateTime(2026, 10));
      expect(range.to, DateTime(2026, 11));
    });
  });

  test('availableMonths lists each start month once, oldest first, without '
      'future periods', () {
    final ps = [
      period('oct', DateTime(2026, 10, 5), []),
      period('sep2', DateTime(2026, 9, 25), []),
      period('sep', DateTime(2026, 9, 5), []),
      period('dec', DateTime(2026, 12, 1), []),
    ];
    expect(availableMonths(ps, today: today), [
      DateTime(2026, 9),
      DateTime(2026, 10),
    ]);
  });

  test('a category subject is keyed by trimmed lower-case name within its '
      'kind', () {
    expect(
      StatsSubject.category(' Groceries ', income: false),
      StatsSubject.category('groceries', income: false),
    );
    expect(
      StatsSubject.category(' Groceries ', income: false).hashCode,
      StatsSubject.category('groceries', income: false).hashCode,
    );
    expect(
      StatsSubject.category('Other', income: false),
      isNot(StatsSubject.category('Other', income: true)),
    );
    expect(
      StatsSubject.category(' Groceries ', income: false).label,
      'Groceries',
    );
  });

  test('only the category subjects have a limit', () {
    expect(StatsSubject.all.hasLimit, isFalse);
    expect(StatsSubject.tag('renovation').hasLimit, isFalse);
    expect(StatsSubject.category('Home', income: false).hasLimit, isTrue);
    expect(StatsSubject.category('Salary', income: true).hasLimit, isTrue);
  });

  test('All and a tag are keyed as the brief says', () {
    expect(StatsSubject.all.label, 'All');
    expect(StatsSubject.all.key, '');
    final tag = StatsSubject.tag('renovation');
    expect(tag.kind, StatsSubjectKind.tag);
    expect(tag.key, 'renovation');
    expect(tag.label, 'renovation');
  });

  test('subjectCatalog groups subjects, names them as in the latest period '
      'and sorts them', () {
    final ps = [
      period('nov', DateTime(2026, 11, 5), [
        category('Groceries'),
        category('home'),
        category('Other'),
        category('Other', type: CategoryType.income),
      ]),
      period('oct', DateTime(2026, 10, 5), [
        category('groceries'),
        category(
          'home',
          type: CategoryType.mandatoryExpense,
          facts: [(900, 'tiles #Renovation')],
        ),
        category(
          'Salary',
          type: CategoryType.income,
          facts: [(5200, '#bonus')],
        ),
      ]),
    ];
    final c = subjectCatalog(ps);
    expect(c.expenses.map((s) => s.label), ['Groceries', 'home', 'Other']);
    expect(c.income.map((s) => s.label), ['Other', 'Salary']);
    expect(c.tags.map((s) => s.label), ['renovation']);
    expect(c.expenses.map((s) => s.kind).toSet(), {
      StatsSubjectKind.expenseCategory,
    });
    expect(c.income.map((s) => s.kind).toSet(), {
      StatsSubjectKind.incomeCategory,
    });
    expect(c.tags.map((s) => s.kind).toSet(), {StatsSubjectKind.tag});
  });

  test('subjectCatalog names a subject as in the newest period, whatever the '
      'list order', () {
    final older = period('oct', DateTime(2026, 10, 5), [category('groceries')]);
    final newer = period('nov', DateTime(2026, 11, 5), [category('Groceries')]);
    expect(subjectCatalog([older, newer]).expenses.single.label, 'Groceries');
    expect(subjectCatalog([newer, older]).expenses.single.label, 'Groceries');
  });

  test('subjectCatalog of no periods is empty', () {
    final c = subjectCatalog(const []);
    expect(c.expenses, isEmpty);
    expect(c.income, isEmpty);
    expect(c.tags, isEmpty);
  });

  test('toggleSubject keeps All exclusive and never leaves nothing ticked', () {
    final g = StatsSubject.category('Groceries', income: false);
    final t = StatsSubject.tag('renovation');
    expect(toggleSubject([StatsSubject.all], g), [g]);
    expect(toggleSubject([g], t), [g, t]);
    expect(toggleSubject([g, t], g), [t]);
    expect(toggleSubject([t], t), [StatsSubject.all]);
    expect(toggleSubject([g, t], StatsSubject.all), [StatsSubject.all]);
    expect(toggleSubject([StatsSubject.all], StatsSubject.all), [
      StatsSubject.all,
    ]);
  });

  group('buildStatsChart', () {
    final groceriesSubject = StatsSubject.category('Groceries', income: false);
    final homeSubject = StatsSubject.category('Home', income: false);
    final giftsSubject = StatsSubject.category('Gifts', income: false);
    final salarySubject = StatsSubject.category('Salary', income: true);

    List<Period> fixture() => [
      period('sep', DateTime(2026, 9, 5), [
        category('Groceries', limit: 800, facts: [(820, null)]),
        category(
          'Home',
          type: CategoryType.mandatoryExpense,
          limit: 1000,
          facts: [(900, 'tiles #renovation')],
        ),
        category(
          'Salary',
          type: CategoryType.income,
          limit: 5000,
          facts: [(5200, null)],
        ),
      ]),
      period('oct', DateTime(2026, 10, 5), [
        category(
          'Groceries',
          limit: 750,
          planned: [500, 400],
          facts: [(700, null), (10, 'paint #renovation #tws')],
        ),
        category(
          'Salary',
          type: CategoryType.income,
          limit: 5000,
          facts: [(5200, '#renovation')],
        ),
      ]),
      period('nov', DateTime(2026, 11, 5), [
        category('Groceries', limit: 700),
        category('Gifts', facts: [(50, null)]),
        category('Salary', type: CategoryType.income, limit: 5000),
      ]),
    ];

    StatsChart chartOf(
      List<StatsSubject> subjects, {
      List<Period>? periods,
      DateTime? now,
      MonthRange? range,
    }) => buildStatsChart(
      allPeriods: periods ?? fixture(),
      subjects: subjects,
      today: now ?? today,
      range: range,
    );

    test('All gives spent and earned lines equal to the dashboard totals', () {
      final ps = fixture();
      final chart = chartOf([StatsSubject.all], periods: ps);
      expect(chart.lines.map((l) => l.label), ['Spent', 'Earned']);
      expect(chart.lines.map((l) => l.role), [
        StatsLineRole.spent,
        StatsLineRole.earned,
      ]);
      expect(chart.lines[0].values, [1720, 710, 50]);
      expect(chart.lines[1].values, [5200, 5200, 0]);
      for (var i = 0; i < 3; i++) {
        final s = periodStatsFor(
          period: chart.periods[i],
          allPeriods: ps,
          now: today,
        );
        expect(chart.lines[0].values[i], s.totalSpent);
        expect(chart.lines[1].values[i], s.totalFactIncome);
      }
      expect(chart.lines.every((l) => l.limits == null), isTrue);
    });

    test('a category line matches its tile, with a gap where the category did '
        'not exist', () {
      final ps = fixture();
      final chart = chartOf([homeSubject, groceriesSubject], periods: ps);
      final home = chart.lines[0];
      final groceries = chart.lines[1];
      expect(home.role, StatsLineRole.value);
      expect(home.label, 'Home');
      expect(home.values, [900, null, null]);
      expect(groceries.values, [820, 710, 0]);

      for (final entry in {'Home': home, 'Groceries': groceries}.entries) {
        for (var i = 0; i < chart.periods.length; i++) {
          final value = entry.value.values[i];
          if (value == null) continue;
          final p = chart.periods[i];
          final tile = categoryStatsFor(
            category: p.categories.firstWhere((c) => c.name == entry.key),
            period: p,
            endDate: effectiveEndDate(p, ps),
            allPeriods: ps,
            now: today,
          );
          expect(value, tile.totalSpent);
        }
      }
    });

    test('lines follow the order of the subjects and the periods the order '
        'of their start dates', () {
      final shuffled = fixture().reversed.toList();
      final chart = chartOf([
        groceriesSubject,
        StatsSubject.all,
        homeSubject,
      ], periods: shuffled);
      expect(chart.periods.map((p) => p.id), ['sep', 'oct', 'nov']);
      expect(chart.lines.map((l) => l.label), [
        'Groceries',
        'Spent',
        'Earned',
        'Home',
      ]);
      expect(chart.lines.first.values, [820, 710, 0]);
    });

    test('a category limit line follows each period\'s effective limit', () {
      final chart = chartOf([groceriesSubject, homeSubject, giftsSubject]);
      // October: the planned 900 outgrew the limit of 750.
      expect(chart.lines[0].limits, [800, 900, 700]);
      expect(chart.lines[1].limits, [1000, null, null]);
      // No limit and nothing planned: no limit to draw.
      expect(chart.lines[2].limits, [null, null, null]);
      expect(chart.lines[2].values, [null, null, 50]);
    });

    test('an income category is its own subject and its limit is the planned '
        'income', () {
      final salary = chartOf([salarySubject]).lines.single;
      expect(salary.values, [5200, 5200, 0]);
      expect(salary.limits, [5000, 5000, 5000]);
    });

    test('expense and income categories sharing a name stay apart', () {
      final ps = [
        period('p', DateTime(2026, 11, 1), [
          category('Other', facts: [(30, null)]),
          category('Other', type: CategoryType.income, facts: [(100, null)]),
        ]),
      ];
      final chart = chartOf([
        StatsSubject.category('Other', income: false),
        StatsSubject.category('Other', income: true),
      ], periods: ps);
      expect(chart.lines[0].values, [30]);
      expect(chart.lines[1].values, [100]);
    });

    test('same-key categories in one period add up, limits too', () {
      final ps = [
        period('p', DateTime(2026, 11, 1), [
          category('Groceries', limit: 300, facts: [(10, null)]),
          category('groceries', limit: 200, facts: [(20, null)]),
        ]),
      ];
      final line = chartOf([groceriesSubject], periods: ps).lines.single;
      expect(line.values, [30]);
      expect(line.limits, [500]);
    });

    test('same-named categories with different ids are told apart by name '
        'and kind, never by id', () {
      final first = category('Groceries', limit: 300, facts: [(10, null)]);
      final second = category('groceries ', limit: 200, facts: [(20, null)]);
      final ps = [
        period('p', DateTime(2026, 11, 1), [
          first.copyWith(id: 'a'),
          second.copyWith(id: 'b'),
        ]),
      ];
      final line = chartOf([groceriesSubject], periods: ps).lines.single;
      expect(line.values, [30]);
      expect(line.limits, [500]);
    });

    test('a tag line sums expense payments carrying it, in full under each '
        'tag', () {
      final chart = chartOf([
        StatsSubject.tag('renovation'),
        StatsSubject.tag('tws'),
      ]);
      final renovation = chart.lines[0];
      final tws = chart.lines[1];
      // Salary's #renovation is income: not counted.
      expect(renovation.values, [900, 10, 0]);
      expect(tws.values, [0, 10, 0]);
      expect(renovation.limits, isNull);
      expect(renovation.role, StatsLineRole.value);
      expect(renovation.label, 'renovation');
    });

    test('a tag repeated in one comment counts the payment once', () {
      final ps = [
        period('p', DateTime(2026, 11, 5), [
          category('Hosting', facts: [(100, 'hosting #tws #tws')]),
        ]),
      ];
      final chart = buildStatsChart(
        allPeriods: ps,
        subjects: [StatsSubject.tag('tws')],
        today: today,
      );
      expect(chart.lines.single.values, [100]);
    });

    test('a subject found nowhere gives gaps for a category and zeros for a '
        'tag', () {
      final chart = chartOf([
        StatsSubject.category('Nope', income: false),
        StatsSubject.tag('nope'),
      ]);
      expect(chart.lines[0].values, [null, null, null]);
      expect(chart.lines[0].limits, [null, null, null]);
      expect(chart.lines[1].values, [0, 0, 0]);
    });

    test('the period covering today is marked in progress', () {
      expect(chartOf([StatsSubject.all]).inProgressIndex, 2);
      expect(
        chartOf([StatsSubject.all], now: DateTime(2027, 3, 1)).inProgressIndex,
        isNull,
      );
    });

    test('the last day of a period is still in progress, whatever the time '
        'of day', () {
      // October runs to November 4, the day before November begins.
      final lastDay = DateTime(2026, 11, 4, 23, 30);
      expect(chartOf([StatsSubject.all], now: lastDay).inProgressIndex, 1);
      expect(
        chartOf([StatsSubject.all], now: DateTime(2026, 10, 5)).inProgressIndex,
        1,
      );
    });

    test('a range limits the periods and moves the in-progress index', () {
      final chart = chartOf([
        groceriesSubject,
      ], range: MonthRange(DateTime(2026, 10), DateTime(2026, 11)));
      expect(chart.periods.map((p) => p.id), ['oct', 'nov']);
      expect(chart.lines.single.values, [710, 0]);
      expect(chart.lines.single.limits, [900, 700]);
      expect(chart.inProgressIndex, 1);
    });

    test('a range does not change where a period ends', () {
      // September ends October 4 because October exists, even though the
      // range leaves October out; on October 5 September is over.
      final chart = chartOf(
        [StatsSubject.all],
        now: DateTime(2026, 10, 5),
        range: MonthRange(DateTime(2026, 9), DateTime(2026, 9)),
      );
      expect(chart.periods.map((p) => p.id), ['sep']);
      expect(chart.inProgressIndex, isNull);
    });

    test('no periods give an empty chart with a line per subject', () {
      final chart = chartOf([StatsSubject.all], periods: const []);
      expect(chart.periods, isEmpty);
      expect(chart.lines, hasLength(2));
      expect(chart.inProgressIndex, isNull);
      expect(chart.isEmpty, isTrue);
    });

    test('isEmpty only when every value is missing or zero', () {
      expect(chartOf([StatsSubject.tag('nope')]).isEmpty, isTrue);
      expect(
        chartOf([StatsSubject.category('Nope', income: false)]).isEmpty,
        isTrue,
      );
      expect(chartOf([StatsSubject.all]).isEmpty, isFalse);
      expect(chartOf([giftsSubject]).isEmpty, isFalse);
    });

    test('tooltipRows lists lines in order and skips gaps', () {
      final chart = chartOf([homeSubject, groceriesSubject]);
      final at0 = tooltipRows(chart, 0);
      expect(at0.map((r) => (r.line.label, r.value, r.limit)), [
        ('Home', 900, 1000),
        ('Groceries', 820, 800),
      ]);
      expect(
        tooltipRows(chart, 1).map((r) => (r.line.label, r.value, r.limit)),
        [('Groceries', 710, 900)],
      );
      expect(tooltipRows(chart, 2).map((r) => r.line.label), ['Groceries']);
    });

    test('tooltipRows of lines without limits carry no limit', () {
      final chart = chartOf([StatsSubject.all]);
      expect(
        tooltipRows(chart, 1).map((r) => (r.line.label, r.value, r.limit)),
        [('Spent', 710, null), ('Earned', 5200, null)],
      );
    });
  });
}
