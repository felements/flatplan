import 'package:flatplan/src/models/models.dart';
import 'package:intl/intl.dart';

/// A EUR period starting on [start], named like the app names new periods.
Period period(String id, DateTime start, List<Category> categories) => Period(
  id: id,
  name: DateFormat('MMMM yy').format(start),
  startDate: start,
  baseCurrency: 'EUR',
  lastModified: start,
  categories: categories,
);

/// A category named [name]; [planned] amounts and [facts] (amount and
/// comment) get ids derived from the name and their index.
Category category(
  String name, {
  CategoryType type = CategoryType.optionalExpense,
  double? limit,
  List<double> planned = const [],
  List<(double, String?)> facts = const [],
}) => Category(
  id: name,
  name: name,
  type: type,
  limit: limit,
  plannedExpenses: [
    for (var i = 0; i < planned.length; i++)
      PlannedExpense(
        id: '$name-p$i',
        description: 'planned $i',
        amount: planned[i],
        dueDate: const DueDate.dayOfMonth(day: 1),
      ),
  ],
  factExpenses: [
    for (var i = 0; i < facts.length; i++)
      FactExpense(
        id: '$name-f$i',
        amount: facts[i].$1,
        description: facts[i].$2,
        timestamp: DateTime(2026, 1, 2),
      ),
  ],
);
