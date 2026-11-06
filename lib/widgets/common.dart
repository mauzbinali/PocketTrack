import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/records.dart';

IconData categoryIcon(String key) => switch (key) {
  'food' => Icons.restaurant_outlined,
  'transport' => Icons.directions_bus_outlined,
  'shopping' => Icons.shopping_bag_outlined,
  'education' => Icons.school_outlined,
  'bills' => Icons.receipt_long_outlined,
  'health' => Icons.favorite_border,
  'entertainment' => Icons.movie_outlined,
  'salary' => Icons.work_outline,
  'allowance' => Icons.account_balance_wallet_outlined,
  'freelance' => Icons.laptop,
  'gift' => Icons.card_giftcard,
  _ => Icons.category_outlined,
};

class CategoryAvatar extends StatelessWidget {
  final Category category;
  const CategoryAvatar(this.category, {super.key});
  @override
  Widget build(BuildContext context) => CircleAvatar(
    backgroundColor: Color(category.color).withValues(alpha: .1),
    foregroundColor: Color(category.color),
    child: Icon(categoryIcon(category.icon)),
  );
}

Future<DateTime?> pickMonth(
  BuildContext context,
  DateTime selected,
) => showDialog<DateTime>(
  context: context,
  builder: (context) {
    var year = selected.year;
    var month = selected.month;
    return StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Choose month'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Previous year',
                  onPressed: year > 1900 ? () => setState(() => year--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('$year', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  tooltip: 'Next year',
                  onPressed: year < 9998 ? () => setState(() => year++) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            DropdownButtonFormField<int>(
              initialValue: month,
              decoration: const InputDecoration(labelText: 'Month'),
              items: List.generate(
                12,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(DateFormat.MMMM().format(DateTime(2000, i + 1))),
                ),
              ),
              onChanged: (v) => month = v!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, DateTime(year, month)),
            child: const Text('Select'),
          ),
        ],
      ),
    );
  },
);

class MonthPicker extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  const MonthPicker({super.key, required this.month, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Previous month',
        onPressed: month.year > 1900 || month.month > 1
            ? () => onChanged(DateTime(month.year, month.month - 1))
            : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: TextButton.icon(
          onPressed: () async {
            final value = await pickMonth(context, month);
            if (value != null && context.mounted) onChanged(value);
          },
          icon: const Icon(Icons.calendar_month_outlined, size: 19),
          label: Text(DateFormat.yMMMM().format(month)),
        ),
      ),
      IconButton(
        tooltip: 'Next month',
        onPressed: month.year < 9998 || month.month < 12
            ? () => onChanged(DateTime(month.year, month.month + 1))
            : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class Panel extends StatelessWidget {
  final Widget child;
  const Panel({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final String? action;
  final VoidCallback? onAction;
  const EmptyState(
    this.title,
    this.message, {
    super.key,
    this.action,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      children: [
        const Icon(
          Icons.account_balance_wallet_outlined,
          size: 44,
          color: Color(0xFF157453),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (onAction != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: FilledButton(onPressed: onAction, child: Text(action!)),
          ),
      ],
    ),
  );
}

class EntryTile extends StatelessWidget {
  final Entry entry;
  final Category category;
  final VoidCallback onTap;
  const EntryTile({
    super.key,
    required this.entry,
    required this.category,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    onTap: onTap,
    leading: CategoryAvatar(category),
    title: Text(category.name),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${DateFormat.MMMd().format(entry.date)}${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          '${entry.type == 'income' ? '+' : '-'}${money(entry.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: entry.type == 'income'
                ? Theme.of(context).colorScheme.primary
                : null,
            fontSize: 14,
          ),
        ),
      ],
    ),
    trailing: const Icon(Icons.chevron_right, size: 18),
  );
}

Future<bool> confirmDelete(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;
