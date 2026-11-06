import '../models/records.dart';
import 'repository.dart';

/// Populate only an empty demo database. Real records are never replaced.
Future<void> seedDemoData(Repository repository, {DateTime? today}) async {
  final now = today ?? DateTime.now();
  await repository.db.transaction((txn) async {
    if ((await txn.query('transactions', limit: 1)).isNotEmpty ||
        (await txn.query('budgets', limit: 1)).isNotEmpty) {
      return;
    }
    for (final offset in [-1, 0]) {
      final month = DateTime(now.year, now.month + offset);
      final lastDay = offset == 0
          ? now.day
          : DateTime(month.year, month.month + 1, 0).day;
      const samples = <(int, int, int, String)>[
        (9, 90000, 1, 'Monthly salary'),
        (11, 15000, 3, 'Freelance design project'),
        (1, 6500, 2, 'Weekly groceries'),
        (1, 4200, 4, 'Dinner with friends'),
        (1, 1800, 6, 'Lunch and coffee'),
        (2, 1600, 2, 'Fuel top-up'),
        (2, 800, 5, 'Ride to work'),
        (3, 8200, 4, 'Shoes and everyday essentials'),
        (4, 3500, 3, 'Online course'),
        (5, 7000, 1, 'Electricity bill'),
        (5, 2500, 3, 'Internet subscription'),
        (6, 1500, 5, 'Pharmacy'),
        (7, 2400, 6, 'Movie night'),
        (8, 600, 2, 'Small household purchases'),
      ];
      for (final (categoryId, rupees, day, note) in samples) {
        final category = defaultCategories.firstWhere(
          (c) => c.id == categoryId,
        );
        final date = DateTime(
          month.year,
          month.month,
          day > lastDay ? lastDay : day,
        );
        await txn.insert(
          'transactions',
          Entry(
            type: category.type,
            amount: (offset == -1 && category.type == 'expense'
                ? rupees * 80
                : rupees * 100),
            categoryId: categoryId,
            date: date,
            note: 'Sample: $note',
            createdAt: date,
          ).toMap(),
        );
      }
      for (final (category, limit) in [
        (1, 10000),
        (2, 6000),
        (3, 10000),
        (5, 12000),
        (7, 4000),
      ]) {
        await txn.insert(
          'budgets',
          Budget(
            categoryId: category,
            year: month.year,
            month: month.month,
            amount: limit * 100,
          ).toMap(),
        );
      }
    }
  });
}
