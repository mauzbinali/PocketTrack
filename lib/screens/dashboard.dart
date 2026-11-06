import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/repository.dart';
import '../data/demo_data.dart';
import '../models/records.dart';
import '../widgets/common.dart';
import 'forms.dart';

class Dashboard extends StatefulWidget {
  final Repository? repository;
  final bool demoMode;
  const Dashboard({super.key, this.repository, this.demoMode = false});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Repository? repository;
  List<Category> categories = [];
  List<Entry> entries = [];
  List<Budget> budgets = [];
  DateTime month = monthStart(DateTime.now());
  late DateTimeRange range;
  final search = TextEditingController();
  String? type;
  int? filterCategory;
  int tab = 0;
  bool loading = true, deleting = false;
  String? error;
  @override
  void initState() {
    super.initState();
    resetRange();
    initialize();
  }

  @override
  void dispose() {
    search.dispose();
    if (widget.repository == null && repository != null) {
      unawaited(repository!.close());
    }
    super.dispose();
  }

  void resetRange() {
    range = DateTimeRange(
      start: month,
      end: DateTime(month.year, month.month + 1, 0),
    );
  }

  Future<void> initialize() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      repository ??=
          widget.repository ??
          await Repository.open(path: widget.demoMode ? ':memory:' : null);
      if (widget.demoMode) await seedDemoData(repository!);
      if (!mounted) {
        if (widget.repository == null) await repository!.close();
        return;
      }
      await reload();
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error =
              'PocketTrack could not open local data. Please retry. Your saved records have not been cleared.';
        });
      }
    }
  }

  Future<void> reload() async {
    final c = await repository!.categories();
    final e = await repository!.entries();
    final b = await repository!.budgets();
    if (mounted) {
      setState(() {
        categories = c;
        entries = e;
        budgets = b;
        loading = false;
        error = null;
      });
    }
  }

  Category category(int id) => categories.firstWhere((c) => c.id == id);
  MonthSummary get summary => MonthSummary(entries, budgets, month);
  void selectMonth(DateTime value) => setState(() {
    month = monthStart(value);
    resetRange();
  });
  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> form({
    Entry? entry,
    Budget? budget,
    bool isBudget = false,
  }) async {
    final saved = await Navigator.push<DateTime>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordForm(
          repository: repository!,
          categories: categories,
          month: month,
          entry: entry,
          budget: budget,
          isBudget: isBudget,
        ),
      ),
    );
    if (!mounted) return;
    if (saved != null) {
      setState(() {
        month = monthStart(saved);
        type = null;
        filterCategory = null;
        search.clear();
        resetRange();
      });
      try {
        await reload();
        message('${isBudget ? 'Budget' : 'Transaction'} saved');
      } catch (_) {
        message('Saved, but refresh failed. Please retry.');
      }
    }
  }

  Future<void> remove({Entry? entry, Budget? budget}) async {
    if (deleting) return;
    setState(() => deleting = true);
    if (!await confirmDelete(
      context,
      'Delete ${entry == null ? 'budget' : 'transaction'}?',
      entry == null
          ? 'Only this budget will be removed. All transactions will be kept.'
          : 'This transaction will be permanently removed.',
    )) {
      if (mounted) setState(() => deleting = false);
      return;
    }
    if (!mounted) return;
    try {
      if (entry != null) {
        await repository!.deleteEntry(entry.id!);
      } else {
        await repository!.deleteBudget(budget!.id!);
      }
      await reload();
      message('Deleted');
    } catch (_) {
      message('Could not delete. Please retry.');
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  Future<void> details(Entry entry) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CategoryAvatar(category(entry.categoryId)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category(entry.categoryId).name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                '${entry.type == 'income' ? '+' : '-'}${money(entry.amount)}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${entry.type == 'income' ? 'Income' : 'Expense'} · ${DateFormat.yMMMMd().format(entry.date)}',
              ),
              const SizedBox(height: 24),
              const Text('NOTE', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SelectableText(entry.note.isEmpty ? 'No note added' : entry.note),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, 'delete'),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, 'edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') await form(entry: entry);
    if (action == 'delete') await remove(entry: entry);
  }

  void showHistory({int? categoryId}) => setState(() {
    tab = 1;
    type = categoryId == null ? null : 'expense';
    filterCategory = categoryId;
    search.clear();
    resetRange();
  });
  Widget heading(String title, {String? action, VoidCallback? onTap}) =>
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (action != null)
              TextButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      );
  Widget totals(MonthSummary s) => Column(
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF173E34), Color(0xFF246C54)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MONTHLY BALANCE',
              style: TextStyle(
                color: Color(0xFFD1E8DA),
                letterSpacing: 1.3,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                money(s.balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              s.balance < 0
                  ? 'Spending is above income this month.'
                  : 'A little clarity. More room to live.',
              style: const TextStyle(color: Color(0xFFD1E8DA)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
          s.income >= 10000000000 ||
          s.expenses >= 10000000000)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            metric(
              'Income',
              s.income,
              const Color(0xFF157453),
              Icons.south_west,
            ),
            metric(
              'Expenses',
              s.expenses,
              const Color(0xFFAD492C),
              Icons.north_east,
            ),
          ],
        )
      else
        Row(
          children: [
            Expanded(
              child: metric(
                'Income',
                s.income,
                const Color(0xFF157453),
                Icons.south_west,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: metric(
                'Expenses',
                s.expenses,
                const Color(0xFFAD492C),
                Icons.north_east,
              ),
            ),
          ],
        ),
    ],
  );
  Widget metric(String title, int value, Color color, IconData icon) {
    final tone = Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(color, Colors.white, .5)!
        : color;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(height: 8),
          Text(title),
          const SizedBox(height: 6),
          Text(
            money(value),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }

  Widget pair(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Flexible(
          child: Text(
            money(value),
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
  Widget breakdown(MonthSummary s) {
    final active =
        categories
            .where((c) => c.type == 'expense' && s.spending(c.id) > 0)
            .toList()
          ..sort((a, b) => s.spending(b.id).compareTo(s.spending(a.id)));
    if (active.isEmpty) {
      return const EmptyState(
        'No expenses this month',
        'Your category breakdown will appear after your first expense.',
      );
    }
    return Panel(
      child: Column(
        children: active.map((c) {
          final spent = s.spending(c.id);
          final share = spent / s.expenses;
          final hasBudget = s.budgets.any((b) => b.categoryId == c.id);
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showHistory(categoryId: c.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        categoryIcon(c.icon),
                        color: Color(c.color),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          money(spent),
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: share,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(9),
                    color: Color(c.color),
                    backgroundColor: const Color(0xFFEEF1ED),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasBudget ? 'Budget set' : 'No budget set',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '${(share * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget insights(MonthSummary s) {
    final previous = MonthSummary(
      entries,
      budgets,
      DateTime(month.year, month.month - 1),
    );
    final now = DateTime.now();
    final days = month == monthStart(now)
        ? now.day
        : DateTime(month.year, month.month + 1, 0).day;
    final difference = s.expenses - previous.expenses;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your month in focus',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          pair('Average daily spending', s.expenses ~/ days),
          if (s.income > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (s.expenses / s.income).clamp(0, 1),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(
              '${(s.expenses / s.income * 100).toStringAsFixed(1)}% of income spent',
            ),
          ],
          if (previous.entries.isNotEmpty) ...[
            const Divider(height: 28),
            Text(
              difference == 0
                  ? 'Spending matches last month.'
                  : '${money(difference.abs())} ${difference > 0 ? 'more' : 'less'} spent than last month.',
            ),
            Text(
              'Compared with the full previous month.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> home() {
    final s = summary;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text(
          'Make every rupee count.',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      totals(s),
      if (s.entries.isNotEmpty) insights(s),
      if (s.entries.isEmpty)
        EmptyState(
          'Your month, a fresh start',
          'Add income or an expense to see where your money goes.',
          action: 'Add transaction',
          onAction: () => form(),
        ),
      heading(
        'Your budget',
        action: 'View budgets',
        onTap: () => setState(() => tab = 2),
      ),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.budgets.isEmpty) const Text('No budgets set for this month.'),
            pair('Total budgeted', s.budgeted),
            pair('Spending in budgeted categories', s.budgetSpending),
            const Divider(),
            pair(
              s.budgeted >= s.budgetSpending
                  ? 'Remaining budget'
                  : 'Over budget',
              (s.budgeted - s.budgetSpending).abs(),
            ),
            if (s.unbudgeted > 0) pair('Unbudgeted spending', s.unbudgeted),
          ],
        ),
      ),
      heading('Spending by category'),
      breakdown(s),
      heading(
        'Recent transactions',
        action: 'View all',
        onTap: () => showHistory(),
      ),
      if (s.entries.isNotEmpty)
        Panel(
          child: Column(
            children: s.entries
                .take(5)
                .map(
                  (e) => EntryTile(
                    entry: e,
                    category: category(e.categoryId),
                    onTap: () => details(e),
                  ),
                )
                .toList(),
          ),
        ),
    ];
  }

  List<Widget> history() {
    final matches = filterEntries(
      entries,
      type: type,
      categoryId: filterCategory,
      start: range.start,
      end: range.end,
    );
    final query = search.text.trim().toLowerCase();
    final filtered = matches
        .where(
          (e) =>
              query.isEmpty ||
              e.note.toLowerCase().contains(query) ||
              category(e.categoryId).name.toLowerCase().contains(query),
        )
        .toList();
    final income = filtered
        .where((e) => e.type == 'income')
        .fold(0, (s, e) => s + e.amount);
    final expenses = filtered
        .where((e) => e.type == 'expense')
        .fold(0, (s, e) => s + e.amount);
    return [
      TextField(
        controller: search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search notes or categories',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(search.clear),
                ),
        ),
      ),
      const SizedBox(height: 16),
      SegmentedButton<String>(
        showSelectedIcon: false,
        style: const ButtonStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
        ),
        segments: const [
          ButtonSegment(value: 'all', label: Text('All')),
          ButtonSegment(value: 'income', label: Text('Income')),
          ButtonSegment(value: 'expense', label: Text('Expenses')),
        ],
        selected: {type ?? 'all'},
        onSelectionChanged: (v) => setState(() {
          type = v.first == 'all' ? null : v.first;
          if (filterCategory != null &&
              type != null &&
              category(filterCategory!).type != type) {
            filterCategory = null;
          }
        }),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<int>(
        key: ValueKey('$type-$filterCategory'),
        initialValue: filterCategory ?? 0,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Category'),
        items: [
          const DropdownMenuItem(value: 0, child: Text('All categories')),
          ...categories
              .where((c) => type == null || c.type == type)
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
        ],
        onChanged: (v) => setState(() => filterCategory = v == 0 ? null : v),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () async {
          final value = await showDateRangePicker(
            context: context,
            firstDate: DateTime(1900),
            lastDate: DateTime(9999),
            initialDateRange: range,
          );
          if (value != null && mounted) setState(() => range = value);
        },
        icon: const Icon(Icons.date_range),
        label: Text(
          '${DateFormat.yMMMd().format(range.start)} – ${DateFormat.yMMMd().format(range.end)}',
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => setState(() {
            type = null;
            filterCategory = null;
            search.clear();
            resetRange();
          }),
          child: const Text('Clear filters'),
        ),
      ),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${filtered.length} ${filtered.length == 1 ? 'transaction' : 'transactions'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            pair('Filtered income', income),
            pair('Filtered expenses', expenses),
            pair('Net amount', income - expenses),
          ],
        ),
      ),
      if (filtered.isEmpty)
        EmptyState(
          entries.isEmpty ? 'No transactions yet' : 'No matching transactions',
          entries.isEmpty
              ? 'Start by recording your first income or expense.'
              : 'Try a different category, type, or date range.',
          action: entries.isEmpty ? 'Add transaction' : null,
          onAction: entries.isEmpty ? () => form() : null,
        ),
      for (var i = 0; i < filtered.length; i++) ...[
        if (i == 0 || dayKey(filtered[i].date) != dayKey(filtered[i - 1].date))
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Text(
              DateFormat.yMMMMEEEEd().format(filtered[i].date),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        EntryTile(
          entry: filtered[i],
          category: category(filtered[i].categoryId),
          onTap: () => details(filtered[i]),
        ),
      ],
    ];
  }

  List<Widget> budgetPage() {
    final s = summary;
    return [
      heading(
        'Plan your spending',
        action: 'Add budget',
        onTap: () => form(isBudget: true),
      ),
      const Text(
        'Set a little aside for what matters. Budgets apply only to the selected month.',
      ),
      const SizedBox(height: 12),
      if (s.budgets.isEmpty)
        EmptyState(
          'Give your money a plan',
          'Create a category budget to track your progress.',
          action: 'Create a budget',
          onAction: () => form(isBudget: true),
        ),
      ...s.budgets.map((b) {
        final spent = s.spending(b.categoryId);
        final remaining = b.amount - spent;
        final status = budgetStatus(spent, b.amount);
        final color = spent > b.amount
            ? const Color(0xFFB3261E)
            : spent * 100 >= b.amount * 80
            ? const Color(0xFF855500)
            : const Color(0xFF157453);
        return Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CategoryAvatar(category(b.categoryId)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category(b.categoryId).name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit budget',
                    onPressed: () => form(budget: b, isBudget: true),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete budget',
                    onPressed: deleting ? null : () => remove(budget: b),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              pair('Budget', b.amount),
              pair('Spent', spent),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (spent / b.amount).clamp(0.0, 1.0),
                minHeight: 9,
                borderRadius: BorderRadius.circular(8),
                color: color,
                backgroundColor: const Color(0xFFEEF1ED),
              ),
              const SizedBox(height: 12),
              Text(
                '$status · ${(spent / b.amount * 100).toStringAsFixed(1)}% used',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${money(remaining.abs())} ${remaining < 0 ? 'over budget' : 'remaining'}',
              ),
            ],
          ),
        );
      }),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_rounded,
            color: Color(0xFF176B51),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ['PocketTrack', 'Transactions', 'Budgets', 'Reports'][tab],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      actions: [
        if (!widget.demoMode)
          IconButton(
            tooltip: 'Explore demo',
            icon: const Icon(Icons.science_outlined),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => const Dashboard(demoMode: true),
              ),
            ),
          ),
        IconButton(
          tooltip: 'Refresh saved records',
          onPressed: loading ? null : initialize,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: EmptyState(
              'Unable to load records',
              error!,
              action: 'Retry',
              onAction: initialize,
            ),
          )
        : SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  key: ValueKey(tab),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  children: [
                    if (widget.demoMode)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'DEMO DATA\nTry adding or editing records. Changes reset when you leave; your real data stays separate.',
                        ),
                      ),
                    MonthPicker(month: month, onChanged: selectMonth),
                    const SizedBox(height: 12),
                    ...switch (tab) {
                      0 => home(),
                      1 => history(),
                      2 => budgetPage(),
                      _ => [
                        totals(summary),
                        insights(summary),
                        heading('Expense breakdown'),
                        const Text(
                          'Tap a category to explore its transactions.',
                        ),
                        breakdown(summary),
                      ],
                    },
                  ],
                ),
              ),
            ),
          ),
    floatingActionButton: repository == null || loading || error != null
        ? null
        : FloatingActionButton.extended(
            onPressed: () => form(isBudget: tab == 2),
            icon: const Icon(Icons.add),
            label: Text(tab == 2 ? 'Budget' : 'Transaction'),
          ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (v) => setState(() => tab = v),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'History'),
        NavigationDestination(
          icon: Icon(Icons.savings_outlined),
          label: 'Budgets',
        ),
        NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Reports'),
      ],
    ),
  );
}
