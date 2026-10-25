import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../data/models.dart';
import '../../../widgets/page.dart';
import '../../../widgets/paper.dart';
import '../../../widgets/vault_visuals.dart';
import '../../bills/presentation/bill_editor.dart';
import '../../focus/controllers/focus_controller.dart';
import '../../vault/presentation/vault_detail_screen.dart';
import '../../vault/presentation/vault_editor.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final session = ref.watch(sessionControllerProvider);
    final vault = ref.watch(vaultItemsProvider);
    final bills = ref.watch(billItemsProvider);
    final sessions = ref.watch(focusSessionsProvider);
    final focus = ref.watch(focusControllerProvider);
    final now = DateTime.now();

    final name = session.profile?.name.trim() ?? '';
    final firstName = name.isEmpty ? '' : name.split(' ').first;
    final greeting = switch (now.hour) {
      < 12 => 'Good morning',
      < 17 => 'Good afternoon',
      _ => 'Good evening',
    };
    final dueBills = bills
        .where((bill) =>
            bill.isActive &&
            bill.nextDueDate != null &&
            bill.urgency != Urgency.later)
        .take(4)
        .toList();
    final activeBills = bills.where((bill) => bill.isActive).toList();
    final overdue =
        activeBills.where((bill) => bill.urgency == Urgency.overdue);
    final weekBills = activeBills.where((bill) {
      final days = bill.daysUntilDue;
      return days != null && days <= 7;
    }).toList();
    final weekTotal =
        weekBills.fold<double>(0, (total, bill) => total + bill.amount);
    final recentVault = vault.take(3).toList();
    final passwords =
        vault.where((item) => item.type == VaultType.password).length;
    final cards = vault.where((item) => item.type == VaultType.card).length;
    final weekSessions = sessions
        .where((item) =>
            item.completed &&
            item.startedAt.isAfter(now.subtract(const Duration(days: 7))))
        .toList();
    final focusMinutes =
        weekSessions.fold<int>(0, (total, item) => total + item.minutes);

    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: firstName.isEmpty ? '$greeting.' : '$greeting, $firstName.',
            subtitle: DateFormat('EEEE, d MMMM yyyy').format(now),
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () =>
                      ref.read(sessionControllerProvider.notifier).lock(),
                  icon: const Icon(Icons.lock_outline_rounded),
                  tooltip: 'Lock vault',
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'Add something',
                  onSelected: (value) {
                    if (value == 'vault') {
                      showVaultEditor(context, ref);
                    } else if (value == 'bill') {
                      showBillEditor(context, ref);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'vault',
                      child: Text('Vault item'),
                    ),
                    PopupMenuItem(
                      value: 'bill',
                      child: Text('Bill or subscription'),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: palette.teal,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 18,
                            color: Theme.of(context).colorScheme.onPrimary),
                        const SizedBox(width: 6),
                        Text(
                          'Add',
                          style: textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 880;
              final todayCard = _TodayCard(
                dueBills: dueBills,
                overdueCount: overdue.length,
                now: now,
              );
              final side = Column(
                children: [
                  _VaultCard(
                    total: vault.length,
                    passwords: passwords,
                    cards: cards,
                    recent: recentVault,
                  ),
                  const SizedBox(height: 16),
                  _FocusCard(
                    focus: focus,
                    minutes: focusMinutes,
                    sessions: weekSessions.length,
                  ),
                ],
              );

              if (!wide) {
                return Column(
                  children: [
                    todayCard,
                    const SizedBox(height: 16),
                    side,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: todayCard),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: side),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _LedgerStrip(
            vaultCount: vault.length,
            weekTotal: weekTotal,
            weekBillCount: weekBills.length,
            focusMinutes: focusMinutes,
            focusSessions: weekSessions.length,
          ),
          if (overdue.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.dangerSoft,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: palette.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, color: palette.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      overdue.length == 1
                          ? '1 bill is past its due date.'
                          : '${overdue.length} bills are past their due date.',
                      style: textTheme.bodyMedium?.copyWith(color: palette.ink),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(shellIndexProvider.notifier).state = 2,
                    child: const Text('Review bills'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayCard extends ConsumerWidget {
  const _TodayCard({
    required this.dueBills,
    required this.overdueCount,
    required this.now,
  });

  final List<BillItem> dueBills;
  final int overdueCount;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    return PaperCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today', style: textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        overdueCount > 0
                            ? '$overdueCount overdue · ${dueBills.length} in the next seven days'
                            : 'What needs your attention next',
                        style:
                            textTheme.bodySmall?.copyWith(color: palette.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  now.day.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 62,
                    fontWeight: FontWeight.w500,
                    height: 0.9,
                    letterSpacing: -2,
                    color: palette.brass.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: palette.line),
          if (dueBills.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: EmptyState(
                compact: true,
                icon: Icons.check_circle_outline_rounded,
                title: 'The next seven days are clear.',
                body:
                    'Add a bill or subscription and Aethel will keep the due date in view.',
                action: FilledButton.tonal(
                  onPressed: () => showBillEditor(context, ref),
                  child: const Text('Add a bill'),
                ),
              ),
            )
          else
            for (var index = 0; index < dueBills.length; index++) ...[
              _DueRow(bill: dueBills[index]),
              if (index < dueBills.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 78),
                  child: Divider(color: palette.line),
                ),
            ],
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
            child: Row(
              children: [
                TextButton(
                  onPressed: () =>
                      ref.read(shellIndexProvider.notifier).state = 2,
                  child: const Text('View the bill ledger'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => showBillEditor(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DueRow extends ConsumerWidget {
  const _DueRow({required this.bill});

  final BillItem bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final urgency = bill.urgency;
    final tone = switch (urgency) {
      Urgency.overdue => palette.danger,
      Urgency.today || Urgency.soon => palette.brass,
      _ => palette.muted,
    };
    final background = switch (urgency) {
      Urgency.overdue => palette.dangerSoft,
      Urgency.today || Urgency.soon => palette.brassSoft,
      _ => palette.ground,
    };
    final date = bill.nextDueDate;
    final label = switch (urgency) {
      Urgency.overdue => 'Overdue',
      Urgency.today => 'Today',
      Urgency.soon => '${bill.daysUntilDue} days',
      _ => 'Later',
    };

    return InkWell(
      onTap: () => showBillEditor(context, ref, item: bill),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 18, 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 48,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    date == null ? '—' : date.day.toString(),
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      color: tone,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date == null
                        ? 'once'
                        : DateFormat('MMM').format(date).toLowerCase(),
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
                  Text(
                    bill.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${bill.type.label} · ${bill.cycle?.label ?? 'One-time'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(bill.amount),
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 5),
                StatusPill(
                  label: label,
                  tone: urgency == Urgency.overdue
                      ? PillTone.danger
                      : urgency == Urgency.today || urgency == Urgency.soon
                          ? PillTone.brass
                          : PillTone.neutral,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultCard extends ConsumerWidget {
  const _VaultCard({
    required this.total,
    required this.passwords,
    required this.cards,
    required this.recent,
  });

  final int total;
  final int passwords;
  final int cards;
  final List<VaultItem> recent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.lock_outline_rounded, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('The strongbox', style: textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      total == 0
                          ? 'Nothing sealed yet'
                          : '$passwords passwords · $cards cards',
                      style:
                          textTheme.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ),
              Text(
                '$total',
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                  color: palette.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recent.isEmpty)
            Text(
              'Passwords, cards, identities and notes live here, encrypted before sync.',
              style: textTheme.bodySmall?.copyWith(
                color: palette.muted,
                height: 1.5,
              ),
            )
          else
            for (final item in recent)
              InkWell(
                onTap: () => showVaultDetail(context, item),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        vaultIcon(item.type),
                        size: 16,
                        color: palette.teal,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      if (item.favorite)
                        Icon(Icons.star_rounded,
                            size: 14, color: palette.brass),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () =>
                    ref.read(shellIndexProvider.notifier).state = 1,
                child: const Text('Open the vault'),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => showVaultEditor(context, ref),
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Add a vault item',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FocusCard extends ConsumerWidget {
  const _FocusCard({
    required this.focus,
    required this.minutes,
    required this.sessions,
  });

  final FocusState focus;
  final int minutes;
  final int sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final run = focus.run;
    final remaining = focus.remainingSeconds;
    final mm = (remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (remaining % 60).toString().padLeft(2, '0');

    return PaperCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.hourglass_empty_rounded,
                size: 38,
                color: palette.brassSoft,
                iconColor: palette.brass,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Focus', style: textTheme.titleLarge),
              ),
              StatusPill(
                label: run == null
                    ? '$sessions this week'
                    : run.paused
                        ? 'Paused'
                        : 'In session',
                tone: run == null ? PillTone.neutral : PillTone.brass,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (run != null) ...[
            Text(
              '$mm:$ss',
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 42,
                fontWeight: FontWeight.w500,
                height: 1,
                letterSpacing: -1,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              run.task,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$minutes',
                  style: TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 42,
                    fontWeight: FontWeight.w500,
                    height: 1,
                    letterSpacing: -1,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    'minutes in seven days',
                    style: textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      ref.read(shellIndexProvider.notifier).state = 3,
                  icon: Icon(
                    run == null
                        ? Icons.play_arrow_rounded
                        : Icons.timer_outlined,
                    size: 18,
                  ),
                  label: Text(run == null ? 'Start a session' : 'Open timer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerStrip extends StatelessWidget {
  const _LedgerStrip({
    required this.vaultCount,
    required this.weekTotal,
    required this.weekBillCount,
    required this.focusMinutes,
    required this.focusSessions,
  });

  final int vaultCount;
  final double weekTotal;
  final int weekBillCount;
  final int focusMinutes;
  final int focusSessions;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final stats = [
      _LedgerStat(
        label: 'In the vault',
        value: '$vaultCount',
        note: 'entries sealed',
      ),
      _LedgerStat(
        label: 'Due this week',
        value: formatMoney(weekTotal),
        note: weekBillCount == 1 ? '1 bill' : '$weekBillCount bills',
      ),
      _LedgerStat(
        label: 'Focused',
        value: '${focusMinutes}m',
        note: focusSessions == 1 ? '1 session' : '$focusSessions sessions',
      ),
    ];

    return PaperCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 620) {
            return Column(
              children: [
                for (var index = 0; index < stats.length; index++) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                    child: stats[index],
                  ),
                  if (index < stats.length - 1) Divider(color: palette.line),
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
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                      child: stats[index],
                    ),
                  ),
                  if (index < stats.length - 1)
                    VerticalDivider(color: palette.line, width: 1),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LedgerStat extends StatelessWidget {
  const _LedgerStat({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

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
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 30,
            fontWeight: FontWeight.w500,
            height: 1.1,
            color: palette.ink,
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
