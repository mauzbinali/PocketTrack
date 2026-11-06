import 'package:intl/intl.dart';

const maxAmount = 999999999999;
int? parsePaisa(String input) {
  final text = input.trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > maxAmount ~/ 100) return null;
  final value =
      whole * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return value > 0 && value <= maxAmount ? value : null;
}

String amountInput(int value) =>
    '${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';
String money(int value) =>
    '${value < 0 ? '-' : ''}PKR ${NumberFormat('#,##0').format(value.abs() ~/ 100)}.${(value.abs() % 100).toString().padLeft(2, '0')}';
String dayKey(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
DateTime monthStart(DateTime value) => DateTime(value.year, value.month);

class Category {
  final int id, color;
  final String name, type, icon;
  const Category(this.id, this.name, this.type, this.icon, this.color);
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'type': type,
    'icon_key': icon,
    'color': color,
  };
  factory Category.fromMap(Map<String, Object?> m) => Category(
    m['id'] as int,
    m['name'] as String,
    m['type'] as String,
    m['icon_key'] as String,
    m['color'] as int,
  );
}

const defaultCategories = [
  Category(1, 'Food', 'expense', 'food', 0xFFB35B30),
  Category(2, 'Transport', 'expense', 'transport', 0xFF3267AE),
  Category(3, 'Shopping', 'expense', 'shopping', 0xFF8954AA),
  Category(4, 'Education', 'expense', 'education', 0xFF346B65),
  Category(5, 'Bills', 'expense', 'bills', 0xFF9A6A16),
  Category(6, 'Health', 'expense', 'health', 0xFFB84758),
  Category(7, 'Entertainment', 'expense', 'entertainment', 0xFF665AB0),
  Category(8, 'Other', 'expense', 'other', 0xFF586779),
  Category(9, 'Salary', 'income', 'salary', 0xFF157453),
  Category(10, 'Allowance', 'income', 'allowance', 0xFF157453),
  Category(11, 'Freelance', 'income', 'freelance', 0xFF157453),
  Category(12, 'Gift', 'income', 'gift', 0xFF157453),
  Category(13, 'Other Income', 'income', 'other', 0xFF157453),
];

class Entry {
  final int? id;
  final String type, note;
  final int amount, categoryId;
  final DateTime date, createdAt;
  Entry({
    this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'type': type,
    'amount': amount,
    'category_id': categoryId,
    'date': dayKey(date),
    'note': note,
    'created_at': createdAt.toIso8601String(),
  };
  factory Entry.fromMap(Map<String, Object?> m) => Entry(
    id: m['id'] as int,
    type: m['type'] as String,
    amount: m['amount'] as int,
    categoryId: m['category_id'] as int,
    date: DateTime.parse(m['date'] as String),
    note: m['note'] as String,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}

class Budget {
  final int? id;
  final int categoryId, year, month, amount;
  const Budget({
    this.id,
    required this.categoryId,
    required this.year,
    required this.month,
    required this.amount,
  });
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'category_id': categoryId,
    'year': year,
    'month': month,
    'amount': amount,
  };
  factory Budget.fromMap(Map<String, Object?> m) => Budget(
    id: m['id'] as int,
    categoryId: m['category_id'] as int,
    year: m['year'] as int,
    month: m['month'] as int,
    amount: m['amount'] as int,
  );
}

List<Entry> filterEntries(
  List<Entry> records, {
  String? type,
  int? categoryId,
  DateTime? start,
  DateTime? end,
}) =>
    records
        .where(
          (e) =>
              (type == null || e.type == type) &&
              (categoryId == null || e.categoryId == categoryId) &&
              (start == null ||
                  !e.date.isBefore(
                    DateTime(start.year, start.month, start.day),
                  )) &&
              (end == null ||
                  e.date.isBefore(DateTime(end.year, end.month, end.day + 1))),
        )
        .toList()
      ..sort((a, b) {
        final date = b.date.compareTo(a.date);
        return date != 0 ? date : (b.id ?? 0).compareTo(a.id ?? 0);
      });

class MonthSummary {
  final List<Entry> entries;
  final List<Budget> budgets;
  MonthSummary(List<Entry> all, List<Budget> allBudgets, DateTime month)
    : entries = filterEntries(
        all,
        start: monthStart(month),
        end: DateTime(month.year, month.month + 1, 0),
      ),
      budgets = allBudgets
          .where((b) => b.year == month.year && b.month == month.month)
          .toList();
  int get income =>
      entries.where((e) => e.type == 'income').fold(0, (s, e) => s + e.amount);
  int get expenses =>
      entries.where((e) => e.type == 'expense').fold(0, (s, e) => s + e.amount);
  int get balance => income - expenses;
  int spending(int category) => entries
      .where((e) => e.type == 'expense' && e.categoryId == category)
      .fold(0, (s, e) => s + e.amount);
  int get budgeted => budgets.fold(0, (s, b) => s + b.amount);
  int get budgetSpending =>
      budgets.fold(0, (s, b) => s + spending(b.categoryId));
  int get unbudgeted => expenses - budgetSpending;
}

String budgetStatus(int spent, int limit) => spent > limit
    ? 'Over budget'
    : spent == limit
    ? 'Fully used'
    : spent * 100 >= limit * 80
    ? 'Near limit'
    : 'On track';
