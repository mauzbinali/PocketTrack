import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/records.dart';

class DuplicateBudget implements Exception {}

class Repository {
  final Database db;
  Repository._(this.db);
  static Future<Repository> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final location =
        path ?? p.join(await f.getDatabasesPath(), 'pockettrack.db');
    final db = await f.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute(
            "CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL CHECK(type IN ('income','expense')), icon_key TEXT NOT NULL, color INTEGER NOT NULL, UNIQUE(id,type))",
          );
          await db.execute(
            "CREATE TABLE transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL CHECK(type IN ('income','expense')), amount INTEGER NOT NULL CHECK(amount > 0 AND amount <= $maxAmount), date TEXT NOT NULL, category_id INTEGER NOT NULL, note TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL, FOREIGN KEY(category_id,type) REFERENCES categories(id,type))",
          );
          await db.execute(
            'CREATE INDEX transactions_date ON transactions(date, category_id)',
          );
          await db.execute(
            'CREATE TABLE budgets (id INTEGER PRIMARY KEY AUTOINCREMENT, category_id INTEGER NOT NULL REFERENCES categories(id), year INTEGER NOT NULL CHECK(year BETWEEN 1900 AND 9999), month INTEGER NOT NULL CHECK(month BETWEEN 1 AND 12), amount INTEGER NOT NULL CHECK(amount > 0 AND amount <= $maxAmount), UNIQUE(category_id,year,month))',
          );
          for (final action in ['INSERT', 'UPDATE']) {
            await db.execute(
              "CREATE TRIGGER budget_expense_${action.toLowerCase()} BEFORE $action ON budgets WHEN (SELECT type FROM categories WHERE id=NEW.category_id) != 'expense' BEGIN SELECT RAISE(ABORT, 'Budgets require expense categories'); END",
            );
          }
          for (final c in defaultCategories) {
            await db.insert('categories', c.toMap());
          }
        },
      ),
    );
    return Repository._(db);
  }

  Future<List<Category>> categories() async => (await db.query(
    'categories',
    orderBy: 'id',
  )).map(Category.fromMap).toList();
  Future<List<Entry>> entries() async => (await db.query(
    'transactions',
    orderBy: 'date DESC, id DESC',
  )).map(Entry.fromMap).toList();
  Future<List<Budget>> budgets() async =>
      (await db.query('budgets')).map(Budget.fromMap).toList();
  Future<void> saveEntry(Entry e) async {
    final now = DateTime.now();
    final day = DateTime(e.date.year, e.date.month, e.date.day);
    if (e.amount <= 0 ||
        e.amount > maxAmount ||
        day.year < 1900 ||
        day.isAfter(DateTime(now.year, now.month, now.day))) {
      throw ArgumentError('Invalid amount or future date');
    }
    if (e.id == null) {
      await db.insert('transactions', e.toMap());
    } else {
      final updated = await db.update(
        'transactions',
        e.toMap(),
        where: 'id = ?',
        whereArgs: [e.id],
      );
      if (updated != 1) throw StateError('Transaction no longer exists');
    }
  }

  Future<void> deleteEntry(int id) async {
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveBudget(Budget b) async {
    try {
      if (b.id == null) {
        await db.insert('budgets', b.toMap());
      } else {
        final updated = await db.update(
          'budgets',
          b.toMap(),
          where: 'id = ?',
          whereArgs: [b.id],
        );
        if (updated != 1) throw StateError('Budget no longer exists');
      }
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) throw DuplicateBudget();
      rethrow;
    }
  }

  Future<void> deleteBudget(int id) async {
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() => db.close();
}
