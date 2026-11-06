import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:pockettrack/data/repository.dart';
import 'package:pockettrack/main.dart';
import 'package:pockettrack/models/records.dart';
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native Android SQLite survives reopen and UI uses saved records',
    (tester) async {
      debugPrint('Android verification: starting storage');
      final path = p.join(
        await getDatabasesPath(),
        'pockettrack_verification.db',
      );
      await deleteDatabase(path);
      var repo = await Repository.open(
        path: path,
      ).timeout(const Duration(seconds: 20));
      debugPrint('Android verification: database opened');
      try {
        await tester.pumpWidget(PocketTrackApp(repository: repo));
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 20),
        );
        debugPrint('Android verification: UI settled');
        expect(find.text('Your month, a fresh start'), findsOneWidget);
        final now = DateTime.now();
        await repo.saveEntry(
          Entry(
            type: 'expense',
            amount: 12000,
            categoryId: 1,
            date: DateTime(now.year, now.month, 1),
            note: 'Verification only',
          ),
        );
        await repo.saveBudget(
          Budget(
            categoryId: 1,
            year: now.year,
            month: now.month,
            amount: 10000,
          ),
        );
        await tester.pumpWidget(const SizedBox());
        await repo.close();
        repo = await Repository.open(path: path);
        expect((await repo.entries()).single.amount, 12000);
        expect((await repo.budgets()).single.amount, 10000);
        await tester.pumpWidget(PocketTrackApp(repository: repo));
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 20),
        );
        debugPrint('Android verification: UI settled');
        await tester.tap(find.text('Budgets').last);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 20),
        );
        debugPrint('Android verification: UI settled');
        expect(find.text('Over budget · 120.0% used'), findsOneWidget);
        await repo.deleteBudget((await repo.budgets()).single.id!);
        expect((await repo.entries()).length, 1);
        await repo.deleteEntry((await repo.entries()).single.id!);
        expect(await repo.entries(), isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await repo.close();
        await deleteDatabase(path);
      }
    },
  );
}
