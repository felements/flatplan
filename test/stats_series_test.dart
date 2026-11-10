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

    test('a line\'s total adds its figures over the charted periods', () {
      // Home has a gap after September; the range keeps October onward.
      final chart = chartOf([StatsSubject.all, homeSubject, groceriesSubject]);
      expect(
        [for (final line in chart.lines) line.total],
        [1720 + 710 + 50, 5200 + 5200 + 0, 900, 820 + 710 + 0],
      );
      final fromOctober = chartOf([
        groceriesSubject,
      ], range: MonthRange(DateTime(2026, 10), DateTime(2026, 11)));
      expect(fromOctober.lines.single.total, 710);
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

  group('the dot behind a click', () {
    final groceries = StatsSubject.category('Groceries', income: false);
    final groceriesIncome = StatsSubject.category('Groceries', income: true);
    final rent = StatsSubject.category('Rent', income: false);
    final salary = StatsSubject.category('Salary', income: true);
    final tws = StatsSubject.tag('tws');
    final renovation = StatsSubject.tag('renovation');

    // October holds two spellings of Groceries (one key), an income category
    // also called Groceries, and payments recorded out of order; two of them
    // at the very same moment.
    List<Period> fixture() => [
      period('sep', DateTime(2026, 9, 5), [
        category(
          'Groceries',
          facts: [(60, '#tws')],
          factTimes: [DateTime(2026, 9, 8)],
        ),
      ]),
      period('oct', DateTime(2026, 10, 5), [
        category(
          'Groceries',
          facts: [(700, 'weekly shop'), (10, 'paint #renovation #tws')],
          factTimes: [DateTime(2026, 10, 20), DateTime(2026, 10, 7, 9)],
        ),
        category(
          'groceries ',
          facts: [(30, 'market #tws #TWS')],
          factTimes: [DateTime(2026, 10, 7, 9)],
        ),
        category(
          'Rent',
          type: CategoryType.mandatoryExpense,
          facts: [(900, 'october rent')],
          factTimes: [DateTime(2026, 10, 5)],
        ),
        category(
          'Groceries',
          type: CategoryType.income,
          facts: [(15, 'refund #tws')],
          factTimes: [DateTime(2026, 10, 9)],
        ),
        category(
          'Salary',
          type: CategoryType.income,
          facts: [(5200, null)],
          factTimes: [DateTime(2026, 10, 6)],
        ),
      ]),
    ];

    StatsChart chartOf(List<StatsSubject> subjects, {MonthRange? range}) =>
        buildStatsChart(
          allPeriods: fixture(),
          subjects: subjects,
          today: today,
          range: range,
        );

    /// The comments of the payments behind [chart]'s line [line] in
    /// October, in the order they are listed.
    List<String?> octoberComments(StatsChart chart, int line) => [
      for (final payment in pointPayments(chart.lines[line], chart.periods[1]))
        payment.fact.description,
    ];

    test('All\'s spent dot lists every expense payment, oldest first', () {
      final chart = chartOf([StatsSubject.all]);
      expect(octoberComments(chart, 0), [
        'october rent',
        'paint #renovation #tws',
        'market #tws #TWS',
        'weekly shop',
      ]);
    });

    test('All\'s earned dot lists every income payment, oldest first', () {
      final chart = chartOf([StatsSubject.all]);
      expect(octoberComments(chart, 1), [null, 'refund #tws']);
    });

    test('a category dot lists every same-named category of its kind', () {
      final chart = chartOf([groceries, groceriesIncome]);
      final payments = pointPayments(chart.lines[0], chart.periods[1]);
      expect(
        [for (final p in payments) (p.fact.description, p.category.name)],
        [
          ('paint #renovation #tws', 'Groceries'),
          ('market #tws #TWS', 'groceries '),
          ('weekly shop', 'Groceries'),
        ],
      );
      expect(octoberComments(chart, 1), ['refund #tws']);
    });

    test(
      'a tag dot lists the expense payments carrying the tag, each once',
      () {
        final chart = chartOf([tws]);
        expect(octoberComments(chart, 0), [
          'paint #renovation #tws',
          'market #tws #TWS',
        ]);
      },
    );

    test('payments recorded at the same moment keep the period\'s order', () {
      // Paint and market share a timestamp; paint's category comes first.
      final chart = chartOf([tws]);
      final reversed = fixture();
      final october = reversed[1].copyWith(
        categories: [
          reversed[1].categories[1],
          reversed[1].categories[0],
          ...reversed[1].categories.skip(2),
        ],
      );
      expect(octoberComments(chart, 0).first, 'paint #renovation #tws');
      expect(
        [
          for (final payment in pointPayments(chart.lines[0], october))
            payment.fact.description,
        ],
        ['market #tws #TWS', 'paint #renovation #tws'],
      );
    });

    test('a long list of payments at one moment keeps the period\'s order', () {
      // Dart sorts short lists stably anyway; past 32 entries it does not.
      final at = DateTime(2026, 10, 7);
      final busy = period('oct', DateTime(2026, 10, 5), [
        category(
          'Groceries',
          facts: [for (var i = 0; i < 40; i++) (i.toDouble(), 'shop $i')],
          factTimes: [for (var i = 0; i < 40; i++) at],
        ),
      ]);
      final chart = StatsChart(
        periods: [busy],
        lines: [
          StatsLine(
            subject: groceries,
            role: StatsLineRole.value,
            values: const [780],
          ),
        ],
      );
      expect(
        [for (final p in pointPayments(chart.lines[0], busy)) p.fact.amount],
        [for (var i = 0; i < 40; i++) i.toDouble()],
      );
    });

    test('every dot\'s payments add up to its figure, and a gap has none', () {
      final chart = chartOf([
        StatsSubject.all,
        groceries,
        groceriesIncome,
        rent,
        salary,
        tws,
        renovation,
      ]);
      for (final line in chart.lines) {
        for (var i = 0; i < chart.periods.length; i++) {
          final payments = pointPayments(line, chart.periods[i]);
          final sum = payments.fold<double>(0, (s, p) => s + p.fact.amount);
          expect(
            sum,
            line.values[i] ?? 0,
            reason: '${line.label} in ${chart.periods[i].id}',
          );
          if (line.values[i] == null) expect(payments, isEmpty);
        }
      }
    });

    group('locatePoint', () {
      test('finds the line and the period of a point', () {
        final chart = chartOf([tws, rent]);
        final point = StatsPoint(
          subject: rent,
          role: StatsLineRole.value,
          periodId: 'oct',
        );
        expect(locatePoint(chart, point), (line: 1, period: 1));
      });

      test('tells All\'s spent dot from its earned one', () {
        final chart = chartOf([StatsSubject.all]);
        StatsPoint at(StatsLineRole role) =>
            StatsPoint(subject: StatsSubject.all, role: role, periodId: 'sep');
        expect(locatePoint(chart, at(StatsLineRole.spent)), (
          line: 0,
          period: 0,
        ));
        expect(locatePoint(chart, at(StatsLineRole.earned)), (
          line: 1,
          period: 0,
        ));
      });

      test('is null once the subject is no longer charted', () {
        final chart = chartOf([tws]);
        final point = StatsPoint(
          subject: rent,
          role: StatsLineRole.value,
          periodId: 'oct',
        );
        expect(locatePoint(chart, point), isNull);
      });

      test('is null once the period is outside the range', () {
        final october = DateTime(2026, 10);
        final chart = chartOf([tws], range: MonthRange(october, october));
        final point = StatsPoint(
          subject: tws,
          role: StatsLineRole.value,
          periodId: 'sep',
        );
        expect(locatePoint(chart, point), isNull);
      });

      test('is null where the line has a gap', () {
        // September has no Rent category.
        final chart = chartOf([rent]);
        final point = StatsPoint(
          subject: rent,
          role: StatsLineRole.value,
          periodId: 'sep',
        );
        expect(locatePoint(chart, point), isNull);
      });

      test('pointAt names the point locatePoint finds again', () {
        final chart = chartOf([StatsSubject.all, tws]);
        for (var line = 0; line < chart.lines.length; line++) {
          for (var i = 0; i < chart.periods.length; i++) {
            expect(locatePoint(chart, pointAt(chart, line, i)), (
              line: line,
              period: i,
            ));
          }
        }
        expect(
          pointAt(chart, 1, 0),
          StatsPoint(
            subject: StatsSubject.all,
            role: StatsLineRole.earned,
            periodId: 'sep',
          ),
        );
      });
    });

    group('nearestLineAt', () {
      StatsLine line(String name, List<double?> values) => StatsLine(
        subject: StatsSubject.category(name, income: false),
        role: StatsLineRole.value,
        values: values,
      );
      final chart = StatsChart(
        periods: fixture(),
        lines: [
          line('A', [60, 40]),
          line('B', [null, 900]),
          line('C', [60, 740]),
        ],
      );

      test('picks the line whose figure is nearest', () {
        expect(nearestLineAt(chart, 1, 850), 1);
        expect(nearestLineAt(chart, 1, 700), 2);
        expect(nearestLineAt(chart, 1, -50), 0);
      });

      test('skips a line with a gap there', () {
        expect(nearestLineAt(chart, 0, 850), 0);
      });

      test('picks the first of lines that meet', () {
        expect(nearestLineAt(chart, 0, 60), 0);
      });

      test('is null when every line has a gap there', () {
        final gaps = StatsChart(
          periods: fixture(),
          lines: [
            line('B', [null, 900]),
          ],
        );
        expect(nearestLineAt(gaps, 0, 10), isNull);
      });
    });
  });
}
