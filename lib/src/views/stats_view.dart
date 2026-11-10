import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../components/stats_line_chart.dart';
import '../components/summary_card.dart';
import '../logic/stats_series.dart';
import '../providers/all_periods_provider.dart';

/// The Stats page: pick what to graph in a list and read its per-period
/// totals on a line chart, over all periods or a span of months.
///
/// Every figure comes from `logic/stats_series.dart`; the view only keeps the
/// selection, the month range and the search text.
class StatsView extends HookConsumerWidget {
  const StatsView({super.key});

  /// The body width from which the list and the graph sit side by side.
  static const _wideFrom = 640.0;

  static final _monthFormat = DateFormat('MMM yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final periodsAsync = ref.watch(allPeriodsProvider);

    final selected = useState<List<StatsSubject>>(const [StatsSubject.all]);
    final range = useState<MonthRange?>(null);
    final query = useState('');
    // Owned here, not by the list card, so the text survives the card moving
    // when the window crosses [_wideFrom].
    final search = useTextEditingController();

    final today = DateTime.now();
    final months = availableMonths(
      periodsAsync.value ?? const [],
      today: today,
    );
    final rangeLabel = switch (range.value) {
      MonthRange(:final from, :final to) =>
        '${_monthFormat.format(from)} – ${_monthFormat.format(to)}',
      null => 'All periods',
    };

    Future<void> chooseRange() async {
      final choice = await showDialog<({MonthRange? range})>(
        context: context,
        builder: (_) => _RangeDialog(months: months, range: range.value),
      );
      if (choice != null && context.mounted) range.value = choice.range;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.show_chart_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Stats',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              OutlinedButton(
                key: const ValueKey('stats-range'),
                // Nothing to pick a range from until a period has started.
                onPressed: months.isEmpty ? null : chooseRange,
                child: Text(rangeLabel),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: periodsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (periods) {
                final chart = buildStatsChart(
                  allPeriods: periods,
                  subjects: selected.value,
                  today: today,
                  range: range.value,
                );
                if (range.value == null && chart.periods.isEmpty) {
                  return Center(
                    child: Text(
                      'No periods to chart yet.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                final colors = statsLineColors(chart, colorScheme);
                // The list is built from every period, so a range never
                // shortens it.
                final list = _SubjectList(
                  key: const ValueKey('stats-list-card'),
                  catalog: subjectCatalog(periods),
                  chart: chart,
                  colors: colors,
                  selected: selected.value,
                  query: query.value,
                  search: search,
                  onQueryChanged: (text) => query.value = text,
                  onToggle: (subject) =>
                      selected.value = toggleSubject(selected.value, subject),
                );
                final graph = _GraphCard(
                  key: const ValueKey('stats-graph-card'),
                  chart: chart,
                  colors: colors,
                );

                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= _wideFrom) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 220, child: list),
                          const SizedBox(width: 16),
                          Expanded(child: SingleChildScrollView(child: graph)),
                        ],
                      );
                    }
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 240, child: list),
                          const SizedBox(height: 16),
                          graph,
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A small filled circle, in a line's colour.
class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// The searchable list of subjects to graph, grouped, with a checkbox each.
class _SubjectList extends StatelessWidget {
  const _SubjectList({
    super.key,
    required this.catalog,
    required this.chart,
    required this.colors,
    required this.selected,
    required this.query,
    required this.search,
    required this.onQueryChanged,
    required this.onToggle,
  });

  final SubjectCatalog catalog;
  final StatsChart chart;

  /// The colour of each line of [chart].
  final List<Color> colors;
  final List<StatsSubject> selected;

  /// What the search box holds, to filter the rows by.
  final String query;
  final TextEditingController search;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<StatsSubject> onToggle;

  static String _label(StatsSubject subject) =>
      subject == StatsSubject.all ? 'All (spent & earned)' : subject.label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final needle = query.trim().toLowerCase();

    final groups = [
      ('TOTALS', const [StatsSubject.all]),
      ('EXPENSES', catalog.expenses),
      ('INCOME', catalog.income),
      ('TAGS', catalog.tags),
    ];

    Widget row(StatsSubject subject) {
      final dots = [
        for (var i = 0; i < chart.lines.length; i++)
          if (chart.lines[i].subject == subject) _Dot(colors[i]),
      ];
      return CheckboxListTile(
        key: ValueKey('stats-subject-${subject.kind.name}-${subject.key}'),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        value: selected.contains(subject),
        onChanged: (_) => onToggle(subject),
        title: Text(_label(subject), overflow: TextOverflow.ellipsis),
        secondary: dots.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: dots),
      );
    }

    return Container(
      decoration: summaryCardDecoration(context),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: search,
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              hintText: 'Search…',
              isDense: true,
              prefixIcon: Icon(Icons.search_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            // The rows paint their hover and ripple on the nearest Material,
            // which the card's own background would otherwise hide.
            child: Material(
              type: MaterialType.transparency,
              child: ListView(
                children: [
                  for (final (title, subjects) in groups)
                    if ([
                          for (final s in subjects)
                            if (_label(s).toLowerCase().contains(needle)) s,
                        ]
                        case final shown when shown.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                        child: Text(
                          title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      for (final subject in shown) row(subject),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The card holding the legend and the chart, or the reason there is none.
class _GraphCard extends StatelessWidget {
  const _GraphCard({super.key, required this.chart, required this.colors});

  final StatsChart chart;

  /// The colour of each line of [chart].
  final List<Color> colors;

  static const _chartHeight = 320.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return Container(
      decoration: summaryCardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Several palette colours are alike: the legend names every line.
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (var i = 0; i < chart.lines.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    _Dot(colors[i]),
                    Text(
                      chart.lines[i].label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (chart.periods.isEmpty)
            Text('No periods in this range.', style: mutedStyle)
          else ...[
            SizedBox(
              height: _chartHeight,
              child: StatsLineChart(chart: chart, colors: colors),
            ),
            if (chart.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Nothing recorded for these subjects in this range.',
                  style: mutedStyle,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Dialog choosing between every period and a span of months. Pops a record
/// holding the chosen range, `null` for every period.
class _RangeDialog extends HookWidget {
  const _RangeDialog({required this.months, required this.range});

  /// The months to pick from, oldest first.
  final List<DateTime> months;

  /// The range in force, to start from.
  final MonthRange? range;

  @override
  Widget build(BuildContext context) {
    final current = range;
    final custom = useState(current != null);
    // A period edited since the range was set may have taken its month away.
    final from = useState(
      current != null && months.contains(current.from)
          ? current.from
          : months.first,
    );
    final to = useState(
      current != null && months.contains(current.to) ? current.to : months.last,
    );

    // The span never runs backwards: moving one end past the other drags the
    // other end along.
    void pickFrom(DateTime month) {
      from.value = month;
      if (month.isAfter(to.value)) to.value = month;
    }

    void pickTo(DateTime month) {
      to.value = month;
      if (month.isBefore(from.value)) from.value = month;
    }

    Widget dropdown(
      String key,
      DateTime value,
      ValueChanged<DateTime> onPicked,
    ) => DropdownButton<DateTime>(
      key: ValueKey(key),
      isExpanded: true,
      value: value,
      items: [
        for (final month in months)
          DropdownMenuItem(
            value: month,
            child: Text(StatsView._monthFormat.format(month)),
          ),
      ],
      onChanged: custom.value ? (month) => onPicked(month!) : null,
    );

    return AlertDialog(
      title: const Text('Period range'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<bool>(
              groupValue: custom.value,
              onChanged: (value) => custom.value = value ?? false,
              child: const Column(
                children: [
                  RadioListTile<bool>(value: false, title: Text('All periods')),
                  RadioListTile<bool>(value: true, title: Text('From – to')),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              spacing: 16,
              children: [
                Expanded(
                  child: dropdown('stats-range-from', from.value, pickFrom),
                ),
                Expanded(child: dropdown('stats-range-to', to.value, pickTo)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, (
            range: custom.value ? MonthRange(from.value, to.value) : null,
          )),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
