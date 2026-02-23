import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'repository_provider.dart';

part 'current_period_provider.g.dart';

@riverpod
class CurrentPeriod extends _$CurrentPeriod {
  Timer? _debounceTimer;

  @override
  FutureOr<Period?> build() async {
    final repo = ref.watch(periodRepositoryProvider);
    final periods = await repo.loadAllPeriods();

    if (periods.isEmpty) {
      return null; // Open setup or empty state
    }

    // Return the most recently modified period as the active one
    periods.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return periods.first;
  }

  /// Sets a brand-new period (e.g. first period on cold start) and
  /// persists it immediately without debouncing.
  Future<void> setPeriod(Period newPeriod) async {
    state = AsyncData(newPeriod);
    final repo = ref.read(periodRepositoryProvider);
    await repo.savePeriod(newPeriod);
  }

  /// Mutates the state and triggers a debounced save.
  void updatePeriod(Period newPeriod) {
    if (state.value == null) return;

    final updatedPeriod = newPeriod.copyWith(lastModified: DateTime.now());
    state = AsyncData(updatedPeriod);
    _debouncedSave(updatedPeriod);
  }

  /// Adds a fact expense to a specific category
  void addFactExpense(String categoryId, FactExpense expense) {
    final current = state.value;
    if (current == null) return;

    final updatedCategories = current.categories.map((cat) {
      if (cat.id == categoryId) {
        return cat.copyWith(factExpenses: [...cat.factExpenses, expense]);
      }
      return cat;
    }).toList();

    updatePeriod(current.copyWith(categories: updatedCategories));
  }

  /// Toggles the isCompleted flag of a specific planned expense
  void togglePlannedExpense(String categoryId, String expenseId) {
    final current = state.value;
    if (current == null) return;

    final updatedCategories = current.categories.map((cat) {
      if (cat.id == categoryId) {
        final updatedPlanned = cat.plannedExpenses.map((planned) {
          if (planned.id == expenseId) {
            return planned.copyWith(isCompleted: !planned.isCompleted);
          }
          return planned;
        }).toList();

        return cat.copyWith(plannedExpenses: updatedPlanned);
      }
      return cat;
    }).toList();

    updatePeriod(current.copyWith(categories: updatedCategories));
  }

  /// Appends a new category to the period.
  void addCategory(Category category) {
    final current = state.value;
    if (current == null) return;

    updatePeriod(
      current.copyWith(categories: [...current.categories, category]),
    );
  }

  /// Replaces a category by matching its `id`.
  void updateCategory(Category updated) {
    final current = state.value;
    if (current == null) return;

    final updatedCategories = current.categories.map((cat) {
      return cat.id == updated.id ? updated : cat;
    }).toList();

    updatePeriod(current.copyWith(categories: updatedCategories));
  }

  /// Removes a category by `id`.
  void removeCategory(String categoryId) {
    final current = state.value;
    if (current == null) return;

    final updatedCategories = current.categories
        .where((cat) => cat.id != categoryId)
        .toList();

    updatePeriod(current.copyWith(categories: updatedCategories));
  }

  /// Removes a fact expense by `expenseId` from the given category.
  void removeFactExpense(String categoryId, String expenseId) {
    final current = state.value;
    if (current == null) return;

    final updatedCategories = current.categories.map((cat) {
      if (cat.id == categoryId) {
        return cat.copyWith(
          factExpenses: cat.factExpenses
              .where((e) => e.id != expenseId)
              .toList(),
        );
      }
      return cat;
    }).toList();

    updatePeriod(current.copyWith(categories: updatedCategories));
  }

  void _debouncedSave(Period period) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final repo = ref.read(periodRepositoryProvider);
        await repo.savePeriod(period);
      } catch (e) {
        print('Failed to auto-save period: $e');
        // Handle error visually via a separate notification provider if needed
      }
    });
  }
}
