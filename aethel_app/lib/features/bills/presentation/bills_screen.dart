import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../data/models.dart';
import '../../../widgets/page.dart';
import '../../../widgets/paper.dart';
import '../../../widgets/sheets.dart';
import 'bill_editor.dart';

enum _BillFilter { all, bills, subscriptions, inactive }

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  _BillFilter _filter = _BillFilter.all;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final bills = ref.watch(billItemsProvider);
    final active = bills.where((bill) => bill.isActive).toList();
    final inactive = bills.where((bill) => !bill.isActive).toList();
    final now = DateTime.now();
    final weekBills = active.where((bill) {
      final days = bill.daysUntilDue;
      return days != null && days <= 7;
    }).toList();
    final weekTotal =
        weekBills.fold<double>(0, (total, bill) => total + bill.amount);
    final overdue =
        active.where((bill) => bill.urgency == Urgency.overdue).length;
    final monthly = active.fold<double>(
      0,
      (total, bill) => total + _monthlyEquivalent(bill),
    );

    final visible = switch (_filter) {
      _BillFilter.all => active,
      _BillFilter.bills =>
        active.where((bill) => bill.type == BillingType.bill).toList(),
      _BillFilter.subscriptions =>
        active.where((bill) => bill.type == BillingType.subscription).toList(),
      _BillFilter.inactive => inactive,
    };

    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'The bill ledger',
            subtitle:
                'Every recurring cost and one-time bill, with the next date in plain sight.',
            action: FilledButton.icon(
              onPressed: () => showBillEditor(context, ref),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('New bill'),
            ),
          ),
          const SizedBox(height: 26),
          _SummaryStrip(
            weekTotal: weekTotal,
            weekCount: weekBills.length,
            overdue: overdue,
            monthly: monthly,
            activeCount: active.length,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('The ledger', style: textTheme.titleLarge),
              const Spacer(),
              Text(
                active.isEmpty ? 'Nothing running' : '${active.length} active',
                style: textTheme.bodySmall?.copyWith(color: palette.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterPill(
                  label: 'All',
                  selected: _filter == _BillFilter.all,
                  onTap: () => setState(() => _filter = _BillFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'Bills',
                  selected: _filter == _BillFilter.bills,
                  onTap: () => setState(() => _filter = _BillFilter.bills),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'Subscriptions',
                  selected: _filter == _BillFilter.subscriptions,
                  onTap: () =>
                      setState(() => _filter = _BillFilter.subscriptions),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'Paused & finished',
                  selected: _filter == _BillFilter.inactive,
                  onTap: () => setState(() => _filter = _BillFilter.inactive),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (bills.isEmpty)
            PaperCard(
              padding: EdgeInsets.zero,
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No bills in the ledger.',
                body:
                    'Add rent, a phone plan, a streaming subscription, or a one-time payment.',
                action: FilledButton.icon(
                  onPressed: () => showBillEditor(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add your first bill'),
                ),
              ),
            )
          else if (visible.isEmpty)
            PaperCard(
              padding: EdgeInsets.zero,
              child: EmptyState(
                compact: true,
                icon: Icons.filter_alt_off_outlined,
                title: 'Nothing in this view.',
                body: 'Choose another filter, or add something new.',
                action: TextButton(
                  onPressed: () => setState(() => _filter = _BillFilter.all),
                  child: const Text('Show everything'),
                ),
              ),
            )
          else
            PaperCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var index = 0; index < visible.length; index++) ...[
                    _BillRow(bill: visible[index]),
                    if (index < visible.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 80),
                        child: Divider(height: 1, color: palette.line),
                      ),
                  ],
                ],
              ),
            ),
          if (_filter == _BillFilter.all && inactive.isNotEmpty) ...[
            const SizedBox(height: 26),
            Row(
              children: [
                Text('Paused & finished', style: textTheme.titleLarge),
                const Spacer(),
                Text(
                  '${inactive.length}',
                  style: textTheme.bodySmall?.copyWith(color: palette.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PaperCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var index = 0; index < inactive.length; index++) ...[
                    _BillRow(bill: inactive[index], muted: true),
                    if (index < inactive.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 80),
                        child: Divider(height: 1, color: palette.line),
                      ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: palette.muted),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Reminders are generated from the due date. Amounts and names stay encrypted; the server only sees the date.',
                    style: textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Today is ${DateFormat('EEEE, d MMMM').format(now)}.',
            style: textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }

  double _monthlyEquivalent(BillItem bill) {
    return switch (bill.cycle) {
      BillingCycle.daily => bill.amount * 30,
      BillingCycle.weekly => bill.amount * 4.33,
      BillingCycle.biweekly => bill.amount * 2.17,
      BillingCycle.monthly => bill.amount,
      BillingCycle.quarterly => bill.amount / 3,
      BillingCycle.yearly => bill.amount / 12,
      null => 0,
    };
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.weekTotal,
    required this.weekCount,
    required this.overdue,
    required this.monthly,
    required this.activeCount,
  });

  final double weekTotal;
  final int weekCount;
  final int overdue;
  final double monthly;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final stats = [
      _SummaryStat(
        label: 'Due in seven days',
        value: formatMoney(weekTotal),
        note: weekCount == 1 ? '1 payment' : '$weekCount payments',
        tone: overdue > 0 ? palette.danger : palette.brass,
      ),
      _SummaryStat(
        label: 'Monthly rhythm',
        value: formatMoney(monthly),
        note: 'normalised from $activeCount active',
        tone: palette.teal,
      ),
      _SummaryStat(
        label: 'Overdue',
        value: '$overdue',
        note: overdue == 1 ? 'needs attention' : 'need attention',
        tone: overdue > 0 ? palette.danger : palette.success,
      ),
    ];

    return PaperCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 660) {
            return Column(
              children: [
                for (var index = 0; index < stats.length; index++) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: stats[index],
                  ),
                  if (index < stats.length - 1)
                    Divider(height: 1, color: palette.line),
                ],
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              children: [
                for (var index = 0; index < stats.length; index++) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                      child: stats[index],
                    ),
                  ),
                  if (index < stats.length - 1)
                    VerticalDivider(width: 1, color: palette.line),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.note,
    required this.tone,
  });

  final String label;
  final String value;
  final String note;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 30,
            fontWeight: FontWeight.w500,
            height: 1.1,
            color: tone,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          note,
          style: textTheme.bodySmall?.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}

class _BillRow extends ConsumerWidget {
  const _BillRow({required this.bill, this.muted = false});

  final BillItem bill;
  final bool muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final urgency = bill.urgency;
    final tone = muted
        ? palette.muted
        : switch (urgency) {
            Urgency.overdue => palette.danger,
            Urgency.today || Urgency.soon => palette.brass,
            _ => palette.teal,
          };
    final background = muted
        ? palette.ground
        : switch (urgency) {
            Urgency.overdue => palette.dangerSoft,
            Urgency.today || Urgency.soon => palette.brassSoft,
            _ => palette.tealSoft,
          };
    final due = bill.nextDueDate;
    final label = muted
        ? 'Inactive'
        : switch (urgency) {
            Urgency.overdue => 'Overdue',
            Urgency.today => 'Today',
            Urgency.soon => '${bill.daysUntilDue} days',
            Urgency.none => 'One-time',
            Urgency.later => 'Later',
          };

    return InkWell(
      onTap: () => showBillEditor(context, ref, item: bill),
      child: Opacity(
        opacity: muted ? 0.68 : 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 15, 10, 15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 52,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      due == null ? '—' : due.day.toString(),
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        color: tone,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      due == null
                          ? 'once'
                          : DateFormat('MMM').format(due).toLowerCase(),
                      style: textTheme.labelSmall?.copyWith(
                        color: tone,
                        fontSize: 9.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          bill.type == BillingType.subscription
                              ? Icons.autorenew_rounded
                              : Icons.receipt_long_outlined,
                          size: 14,
                          color: palette.muted,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            bill.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall,
                          ),
                        ),
                        if (bill.pending) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: palette.brass,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${bill.type.label} · ${bill.cycle?.label ?? 'One-time'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          textTheme.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatMoney(bill.amount), style: textTheme.titleSmall),
                  const SizedBox(height: 5),
                  StatusPill(
                    label: label,
                    tone: muted
                        ? PillTone.neutral
                        : urgency == Urgency.overdue
                            ? PillTone.danger
                            : urgency == Urgency.today ||
                                    urgency == Urgency.soon
                                ? PillTone.brass
                                : PillTone.neutral,
                  ),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'Bill actions',
                onSelected: (value) async {
                  if (value == 'edit') {
                    await showBillEditor(context, ref, item: bill);
                  } else if (value == 'paid') {
                    await ref.read(dataActionsProvider).markBillPaid(bill);
                    if (context.mounted) {
                      showMessage(
                        context,
                        bill.cycle == null
                            ? 'Marked paid and closed.'
                            : 'Marked paid. Next date moved forward.',
                      );
                    }
                  } else if (value == 'toggle') {
                    await ref.read(dataActionsProvider).saveBill(
                          bill.copyWith(isActive: !bill.isActive),
                        );
                  } else if (value == 'delete') {
                    final confirmed = await showConfirmDialog(
                      context: context,
                      title: 'Delete this bill?',
                      message:
                          '“${bill.title}” will be removed from this device and the synced ledger.',
                      confirmLabel: 'Delete',
                      destructive: true,
                    );
                    if (confirmed) {
                      await ref.read(dataActionsProvider).deleteBill(bill.id);
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (bill.isActive)
                    const PopupMenuItem(
                      value: 'paid',
                      child: Text('Mark as paid'),
                    ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(bill.isActive ? 'Pause' : 'Reactivate'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: palette.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? palette.teal : palette.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? palette.teal : palette.line),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : palette.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
