import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pockettrack/models/records.dart';
import 'package:pockettrack/data/repository.dart';

void main() {
  test('Money parses exactly into integer paisa', () {
    expect(parsePaisa('0.01'), 1);
    expect(parsePaisa('12.3'), 1230);
    expect(parsePaisa('9999999999.99'), maxAmount);
    for (final invalid in [
      '0',
      '-1',
      '1.001',
      'NaN',
      '1e2',
      '',
      '99999999999',
    ]) {
      expect(parsePaisa(invalid), isNull);
    }
    expect(money(-123456), '-PKR 1,234.56');
  });
  test(
    'Combined filters, month boundaries, income exclusion and budget statuses',
    () {
      final records = [
        Entry(
          id: 1,
          type: 'expense',
          amount: 100,
          categoryId: 1,
          date: DateTime(2025, 1, 31),
        ),
        Entry(
          id: 2,
          type: 'expense',
          amount: 250,
          categoryId: 2,
          date: DateTime(2025, 1, 31),
        ),
        Entry(
          id: 3,
          type: 'income',
          amount: 1000,
          categoryId: 9,
          date: DateTime(2025, 1, 1),
        ),
        Entry(
          id: 4,
          type: 'expense',
          amount: 900,
          categoryId: 1,
          date: DateTime(2025, 2, 1),
        ),
      ];
      final s = MonthSummary(records, [
        const Budget(categoryId: 1, year: 2025, month: 1, amount: 80),
      ], DateTime(2025, 1));
      expect(s.income, 1000);
      expect(s.expenses, 350);
      expect(s.balance, 650);
      expect(s.spending(1), 100);
      expect(s.budgetSpending, 100);
      expect(s.unbudgeted, 250);
      expect(
        filterEntries(
          records,
          type: 'expense',
          categoryId: 1,
          start: DateTime(2025, 1, 1),
          end: DateTime(2025, 1, 31),
        ).map((e) => e.id),
        [1],
      );
      expect(s.entries.map((e) => e.id), [2, 1, 3]);
      expect(budgetStatus(79, 100), 'On track');
      expect(budgetStatus(80, 100), 'Near limit');
      expect(budgetStatus(100, 100), 'Fully used');
      expect(budgetStatus(101, 100), 'Over budget');
      final empty = MonthSummary(records, [], DateTime(2024));
      expect(empty.expenses, 0);
      expect(empty.balance, 0);
    },
  );
  sqfliteFfiInit();
  test(
    'Calendar-day validation and stale edits protect stored records',
    () async {
      final repo = await Repository.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      try {
        final now = DateTime.now();
        await repo.saveEntry(
          Entry(type: 'expense', amount: 1, categoryId: 1, date: now),
        );
        expect(dayKey((await repo.entries()).single.date), dayKey(now));
        for (final date in [
          DateTime(1899),
          DateTime(now.year, now.month, now.day + 1),
        ]) {
          await expectLater(
            repo.saveEntry(
              Entry(type: 'expense', amount: 1, categoryId: 1, date: date),
            ),
            throwsArgumentError,
          );
        }
        await expectLater(
          repo.saveEntry(
            Entry(
              id: 999,
              type: 'expense',
              amount: 1,
              categoryId: 1,
              date: now,
            ),
          ),
          throwsStateError,
        );
        await expectLater(
          repo.saveBudget(
            Budget(
              id: 999,
              categoryId: 1,
              year: now.year,
              month: now.month,
              amount: 100,
            ),
          ),
          throwsStateError,
        );
        expect((await repo.entries()).length, 1);
      } finally {
        await repo.close();
      }
    },
  );
  test(
    'SQLite CRUD, duplicate budgets, retroactive spending and reopen persistence',
    () async {
      final dir = await Directory.systemTemp.createTemp('pockettrack_test_');
      final path = '${dir.path}/records.db';
      var repo = await Repository.open(factory: databaseFactoryFfi, path: path);
      try {
        expect((await repo.categories()).length, 13);
        expect(await repo.entries(), isEmpty);
        await repo.saveEntry(
          Entry(
            type: 'expense',
            amount: 12000,
            categoryId: 1,
            date: DateTime(2025, 1, 15),
            note: 'Lunch',
          ),
        );
        await repo.saveEntry(
          Entry(
            type: 'income',
            amount: 50000,
            categoryId: 9,
            date: DateTime(2025, 1, 1),
          ),
        );
        await repo.saveBudget(
          const Budget(categoryId: 1, year: 2025, month: 1, amount: 10000),
        );
        await expectLater(
          repo.saveBudget(
            const Budget(categoryId: 1, year: 2025, month: 1, amount: 999),
          ),
          throwsA(isA<DuplicateBudget>()),
        );
        var s = MonthSummary(
          await repo.entries(),
          await repo.budgets(),
          DateTime(2025, 1),
        );
        expect(s.budgetSpending, 12000);
        expect(s.budgeted - s.budgetSpending, -2000);
        final entry = (await repo.entries()).first;
        await repo.saveEntry(
          Entry(
            id: entry.id,
            type: 'expense',
            amount: 14000,
            categoryId: 2,
            date: DateTime(2025, 2, 1),
            note: 'Moved',
            createdAt: entry.createdAt,
          ),
        );
        s = MonthSummary(
          await repo.entries(),
          await repo.budgets(),
          DateTime(2025, 1),
        );
        expect(s.expenses, 0);
        expect(s.balance, 50000);
        expect(s.budgetSpending, 0);
        expect(
          MonthSummary(
            await repo.entries(),
            await repo.budgets(),
            DateTime(2025, 2),
          ).spending(2),
          14000,
        );
        await repo.close();
        repo = await Repository.open(factory: databaseFactoryFfi, path: path);
        expect((await repo.categories()).length, 13);
        expect((await repo.entries()).length, 2);
        expect((await repo.entries()).first.note, 'Moved');
        expect((await repo.budgets()).length, 1);
        final budget = (await repo.budgets()).single;
        await repo.saveBudget(
          Budget(
            id: budget.id,
            categoryId: 1,
            year: 2025,
            month: 1,
            amount: 15000,
          ),
        );
        expect((await repo.budgets()).single.amount, 15000);
        await repo.deleteBudget(budget.id!);
        expect((await repo.entries()).length, 2);
        await repo.saveEntry(
          Entry(
            id: entry.id,
            type: 'income',
            amount: 1000,
            categoryId: 10,
            date: DateTime(2025, 2, 1),
          ),
        );
        s = MonthSummary(await repo.entries(), [], DateTime(2025, 2));
        expect(s.expenses, 0);
        expect(s.income, 1000);
        await expectLater(
          repo.saveEntry(
            Entry(
              type: 'income',
              amount: 1,
              categoryId: 1,
              date: DateTime(2025),
            ),
          ),
          throwsA(isA<DatabaseException>()),
        );
        await repo.deleteEntry(entry.id!);
        expect((await repo.entries()).length, 1);
      } finally {
        await repo.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
