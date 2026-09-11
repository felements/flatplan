import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flatplan/src/components/category_dialog.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'dart:io';

void main() {
  testWidgets('offers a big-purchase threshold once daily allowance is on', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync('flatplan_dialog_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final repo = PeriodRepository(directoryPath: tempDir.path);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showCategoryDialog(
                    context,
                    ref,
                    const Category(
                      id: 'c1',
                      name: 'Groceries',
                      isDailyAllowance: true,
                    ),
                    periodId: 'p1',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Big-purchase threshold'), findsOneWidget);
  });
}
