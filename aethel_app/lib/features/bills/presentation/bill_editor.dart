import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/data_actions.dart';
import '../../../data/models.dart';
import '../../premium/premium_controller.dart';
import '../../premium/upgrade_sheet.dart';
import '../../../widgets/page.dart';
import '../../../widgets/sheets.dart';

Future<BillItem?> showBillEditor(
  BuildContext context,
  WidgetRef ref, {
  BillItem? item,
}) async {
  if (item == null &&
      !canCreateWithState(
        ref.read(premiumControllerProvider),
        PremiumKind.billingItem,
        ref.read(billItemsProvider).length,
      )) {
    await showUpgradeSheet(context);
    return null;
  }
  return showAethelSheet<BillItem>(
    context: context,
    builder: (sheetContext) => _BillEditorSheet(
      actions: ref.read(dataActionsProvider),
      item: item,
    ),
  );
}

class _BillEditorSheet extends StatefulWidget {
  const _BillEditorSheet({required this.actions, this.item});

  final DataActions actions;
  final BillItem? item;

  @override
  State<_BillEditorSheet> createState() => _BillEditorSheetState();
}

class _BillEditorSheetState extends State<_BillEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  late BillingType _type;
  late BillingCycle? _cycle;
  late DateTime? _date;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?.title ?? '');
    _amount = TextEditingController(
      text: item == null
          ? ''
          : item.amount == item.amount.roundToDouble()
              ? item.amount.toStringAsFixed(0)
              : item.amount.toStringAsFixed(2),
    );
    _notes = TextEditingController(text: item?.notes ?? '');
    _type = item?.type ?? BillingType.bill;
    _cycle = item?.cycle;
    _date = item?.nextDueDate;
    _active = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      helpText: 'When is it next due?',
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cycle != null && _date == null) {
      setState(() {
        _error = 'Choose the next due date so reminders can be scheduled.';
      });
      return;
    }
    final amount = double.tryParse(
      _amount.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final existing = widget.item;
    final bill = BillItem(
      id: existing?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      amount: amount,
      type: _type,
      cycle: _cycle,
      nextDueDate: _date,
      notes: _notes.text.trim(),
      isActive: _active,
      lastPaidAt: existing?.lastPaidAt,
      pending: true,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      final saved = await widget.actions.saveBill(bill);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on FreeLimitExceededException catch (_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pop();
      await showUpgradeSheet(navigator.context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this bill. $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final editing = widget.item != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          title: editing ? 'Edit bill' : 'New bill',
          subtitle: 'Keep the due date honest and the rest stays encrypted.',
          trailing: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    ErrorBanner(
                      message: _error!,
                      onDismiss: () => setState(() => _error = null),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const FieldLabel('What is it?'),
                  TextFormField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Home internet',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Give this bill a name.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('Amount'),
                  TextFormField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      prefixText: '  ',
                      hintText: '0.00',
                    ),
                    validator: (value) {
                      final parsed =
                          double.tryParse((value ?? '').replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) {
                        return 'Enter an amount above zero.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  const FieldLabel('Kind'),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Bill'),
                        selected: _type == BillingType.bill,
                        showCheckmark: false,
                        onSelected: (_) =>
                            setState(() => _type = BillingType.bill),
                      ),
                      ChoiceChip(
                        label: const Text('Subscription'),
                        selected: _type == BillingType.subscription,
                        showCheckmark: false,
                        onSelected: (_) =>
                            setState(() => _type = BillingType.subscription),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const FieldLabel('Repeats'),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_cycle?.name ?? 'none'),
                    initialValue: _cycle?.name ?? 'none',
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: [
                      const DropdownMenuItem(
                        value: 'none',
                        child: Text('One-time — no repeat'),
                      ),
                      for (final cycle in BillingCycle.values)
                        DropdownMenuItem(
                          value: cycle.name,
                          child: Text(cycle.label),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _cycle = BillingCycle.fromName(value);
                        if (_cycle != null && _date == null) {
                          _date = DateTime.now();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  FieldLabel(
                    _cycle == null ? 'Due date' : 'Next due date',
                    hint: 'Optional for one-time bills',
                  ),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.line),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_outlined,
                              size: 19, color: palette.muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _date == null
                                  ? 'No date'
                                  : DateFormat('EEE, d MMM yyyy')
                                      .format(_date!),
                              style: textTheme.bodyMedium?.copyWith(
                                color:
                                    _date == null ? palette.muted : palette.ink,
                              ),
                            ),
                          ),
                          if (_date != null)
                            IconButton(
                              onPressed: () => setState(() => _date = null),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              tooltip: 'Clear date',
                              visualDensity: VisualDensity.compact,
                            )
                          else
                            Icon(Icons.chevron_right_rounded,
                                color: palette.muted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const FieldLabel('Notes', hint: 'Optional'),
                  TextFormField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Account number, what it covers, a reminder',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                    decoration: BoxDecoration(
                      color: palette.ground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.line),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _active
                              ? Icons.play_circle_outline_rounded
                              : Icons.pause_circle_outline_rounded,
                          size: 20,
                          color: _active ? palette.teal : palette.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Active', style: textTheme.bodyMedium),
                              Text(
                                _active
                                    ? 'Counted in reminders and totals.'
                                    : 'Kept in the ledger, but not counted.',
                                style: textTheme.bodySmall
                                    ?.copyWith(color: palette.muted),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _active,
                          onChanged: (value) => setState(() => _active = value),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(top: BorderSide(color: palette.line)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(editing ? 'Save changes' : 'Add to the ledger'),
            ),
          ),
        ),
      ],
    );
  }
}
