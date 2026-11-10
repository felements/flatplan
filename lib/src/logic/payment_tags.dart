import '../models/models.dart';

/// A payment comment split into its plain text and its `#tags`.
class TaggedText {
  const TaggedText({required this.text, required this.tags});

  /// The comment with every tag cut out.
  final String text;

  /// Lowercased tags in the order they were first written, without repeats.
  final List<String> tags;
}

/// A tag's spending in one period and across every period.
class TagTotal {
  const TagTotal({
    required this.tag,
    required this.periodTotal,
    required this.allPeriodsTotal,
  });

  final String tag;
  final double periodTotal;
  final double allPeriodsTotal;
}

/// `#` that starts the comment or follows whitespace, then letters (any
/// script), digits, `_` or `-`. A `#` inside a word ("C#") is not a tag.
final _tagPattern = RegExp(r'(?<!\S)#([\p{L}\p{M}\p{N}_\-]+)', unicode: true);

/// Digits alone are an order or invoice number ("order #12345"), not a tag.
final _numberOnly = RegExp(r'^\p{N}+$', unicode: true);

/// Splits [description] into its text and its tags.
///
/// Tags are cut wherever they sit, so "tiles #renovation for the bathroom"
/// reads "tiles for the bathroom". Comments without tags come back as typed.
TaggedText splitTags(String? description) {
  if (description == null || description.isEmpty) {
    return const TaggedText(text: '', tags: []);
  }

  final tags = <String>[];
  final text = StringBuffer();
  var last = 0;
  for (final match in _tagPattern.allMatches(description)) {
    final name = match.group(1)!;
    if (_numberOnly.hasMatch(name)) continue;
    final tag = name.toLowerCase();
    if (!tags.contains(tag)) tags.add(tag);
    text.write(description.substring(last, match.start));
    last = match.end;
  }
  if (tags.isEmpty) return TaggedText(text: description, tags: const []);
  text.write(description.substring(last));

  final cleaned = text
      .toString()
      .replaceAll(RegExp(r'\s+'), ' ')
      // "tiles #renovation, grout" must read "tiles, grout".
      .replaceAll(RegExp(r' (?=[,.;:!?])'), '')
      .trim()
      // "#renovation, tiles" must read "tiles".
      .replaceFirst(RegExp(r'^[,;:]\s*'), '');
  return TaggedText(text: cleaned, tags: tags);
}

/// The [limit] tags with the most spending in [period], each with its total
/// there and across every period in [allPeriods].
///
/// A payment with several tags counts in full under each one, so the totals
/// can add up to more than was spent. Income is not spending and is skipped.
/// [period] is used as given; a copy of it in [allPeriods] is ignored, so a
/// stale list cannot under-count the period on screen.
List<TagTotal> topTags({
  required Period period,
  required List<Period> allPeriods,
  int limit = 5,
}) {
  final inPeriod = _spendingByTag(period);
  if (inPeriod.isEmpty) return const [];

  final overall = Map<String, double>.of(inPeriod);
  for (final other in allPeriods) {
    if (other.id == period.id) continue;
    _spendingByTag(other).forEach((tag, sum) {
      overall.update(tag, (v) => v + sum, ifAbsent: () => sum);
    });
  }

  final ranked = inPeriod.entries.toList()
    ..sort((a, b) {
      final bySum = b.value.compareTo(a.value);
      return bySum != 0 ? bySum : a.key.compareTo(b.key);
    });
  return [
    for (final entry in ranked.take(limit))
      TagTotal(
        tag: entry.key,
        periodTotal: entry.value,
        allPeriodsTotal: overall[entry.key]!,
      ),
  ];
}

Map<String, double> _spendingByTag(Period period) {
  final sums = <String, double>{};
  for (final category in period.categories) {
    if (category.type == CategoryType.income) continue;
    for (final fact in category.factExpenses) {
      for (final tag in splitTags(fact.description).tags) {
        sums.update(tag, (v) => v + fact.amount, ifAbsent: () => fact.amount);
      }
    }
  }
  return sums;
}
