import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/repository.dart';
import '../models/records.dart';
import '../widgets/common.dart';

class RecordForm extends StatefulWidget {
  final Repository repository;
  final List<Category> categories;
  final Entry? entry;
  final Budget? budget;
  final bool isBudget;
  final DateTime month;
  const RecordForm({
    super.key,
    required this.repository,
    required this.categories,
    required this.month,
    this.entry,
    this.budget,
    this.isBudget = false,
  });
  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  final key = GlobalKey<FormState>();
  late final TextEditingController amount, note;
  late String type;
  late DateTime date;
  int? category;
  bool busy = false, leaving = false, confirmingLeave = false;
  String? error;
  late String initial;
  String get signature =>
      '$type|$category|${dayKey(date)}|${amount.text}|${note.text}';
  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    final b = widget.budget;
    type = e?.type ?? 'expense';
    category = e?.categoryId ?? b?.categoryId;
    date = widget.isBudget
        ? (b == null ? widget.month : DateTime(b.year, b.month))
        : e?.date ??
              (widget.month.isBefore(monthStart(DateTime.now()))
                  ? widget.month
                  : DateTime.now());
    final value = e?.amount ?? b?.amount;
    amount = TextEditingController(
      text: value == null ? '' : amountInput(value),
    );
    note = TextEditingController(text: e?.note ?? '');
    initial = signature;
    amount.addListener(changed);
    note.addListener(changed);
  }

  void changed() {
    setState(() => error = null);
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (busy || leaving || confirmingLeave) return;
    if (signature != initial) {
      confirmingLeave = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your unsaved changes will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      confirmingLeave = false;
      if (discard != true || !mounted) return;
    }
    setState(() => leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> save() async {
    if (busy || !key.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.isBudget) {
        await widget.repository.saveBudget(
          Budget(
            id: widget.budget?.id,
            categoryId: category!,
            year: date.year,
            month: date.month,
            amount: parsePaisa(amount.text)!,
          ),
        );
      } else {
        await widget.repository.saveEntry(
          Entry(
            id: widget.entry?.id,
            type: type,
            amount: parsePaisa(amount.text)!,
            categoryId: category!,
            date: DateTime(date.year, date.month, date.day),
            note: note.text.trim(),
            createdAt: widget.entry?.createdAt,
          ),
        );
      }
      if (!mounted) return;
      setState(() => leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, date);
      });
    } on DuplicateBudget {
      if (!mounted) return;
      setState(() {
        error =
            'A budget already exists for this category and month. Open Budgets, select that month, and tap its edit button.';
        busy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'Could not save. Your changes are still here; please try again.';
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.entry != null || widget.budget != null;
    return PopScope(
      canPop: leaving || (!busy && signature == initial),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: busy ? null : leave,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            '${editing ? 'Edit' : 'Add'} ${widget.isBudget ? 'budget' : 'transaction'}',
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: key,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (!widget.isBudget) ...[
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'expense',
                          label: Text('Expense'),
                          icon: Icon(Icons.north_east),
                        ),
                        ButtonSegment(
                          value: 'income',
                          label: Text('Income'),
                          icon: Icon(Icons.south_west),
                        ),
                      ],
                      selected: {type},
                      onSelectionChanged: busy
                          ? null
                          : (v) => setState(() {
                              type = v.first;
                              category = null;
                            }),
                    ),
                    const SizedBox(height: 24),
                  ],
                  TextFormField(
                    controller: amount,
                    enabled: !busy,
                    autofocus: !editing,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'PKR ',
                      helperText: 'Use up to 2 decimal places',
                      errorMaxLines: 3,
                    ),
                    validator: (v) => parsePaisa(v ?? '') == null
                        ? 'Enter an amount from 0.01 to 9,999,999,999.99'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    key: ValueKey('$type-$category'),
                    initialValue: category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: widget.categories
                        .where((c) => c.type == type)
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (v) => setState(() => category = v),
                    validator: (v) => v == null ? 'Choose a category' : null,
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFCBD5D0)),
                    ),
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: Text(
                      widget.isBudget ? 'Budget month' : 'Transaction date',
                    ),
                    subtitle: Text(
                      (widget.isBudget
                              ? DateFormat.yMMMM()
                              : DateFormat.yMMMd())
                          .format(date),
                    ),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: busy
                        ? null
                        : () async {
                            final value = widget.isBudget
                                ? await pickMonth(context, date)
                                : await showDatePicker(
                                    context: context,
                                    initialDate: date,
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                  );
                            if (value != null && mounted) {
                              setState(() => date = value);
                            }
                          },
                  ),
                  if (!widget.isBudget) ...[
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: note,
                      enabled: !busy,
                      maxLines: 3,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: busy ? null : save,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      busy
                          ? 'Saving…'
                          : 'Save ${widget.isBudget ? 'budget' : 'transaction'}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
