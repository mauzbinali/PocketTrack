import 'package:flutter_test/flutter_test.dart';
import 'package:pockettrack/data/demo_data.dart';
import 'package:pockettrack/data/repository.dart';
import 'package:pockettrack/models/records.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  test(
    'Demo shows varied budgets, two months, and no future dates or duplicates',
    () async {
      final repo = await Repository.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      try {
        final today = DateTime(2026, 1, 1);
        await seedDemoData(repo, today: today);
        final entries = await repo.entries();
        final budgets = await repo.budgets();
        expect(entries.length, 28);
        expect(budgets.length, 10);
        expect(entries.every((e) => !e.date.isAfter(today)), isTrue);
        final summary = MonthSummary(entries, budgets, today);
        expect(summary.income, 10500000);
        expect(budgetStatus(summary.spending(1), 1000000), 'Over budget');
        expect(budgetStatus(summary.spending(3), 1000000), 'Near limit');
        expect(budgetStatus(summary.spending(2), 600000), 'On track');
        expect(summary.unbudgeted, greaterThan(0));
        expect(
          MonthSummary(entries, budgets, DateTime(2025, 12)).expenses,
          greaterThan(0),
        );
        await seedDemoData(repo, today: today);
        expect((await repo.entries()).length, 28);
        expect((await repo.budgets()).length, 10);
      } finally {
        await repo.close();
      }
    },
  );
  test('Seeding refuses to mix samples into an existing database', () async {
    final repo = await Repository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    try {
      await repo.saveEntry(
        Entry(
          type: 'expense',
          amount: 100,
          categoryId: 1,
          date: DateTime(2025),
        ),
      );
      await seedDemoData(repo);
      expect((await repo.entries()).length, 1);
      expect(await repo.budgets(), isEmpty);
    } finally {
      await repo.close();
    }
  });
}
