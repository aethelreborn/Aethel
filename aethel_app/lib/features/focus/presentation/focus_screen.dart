import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../data/models.dart';
import '../../../widgets/app_picker.dart';
import '../../../widgets/page.dart';
import '../../../widgets/paper.dart';
import '../../../widgets/sheets.dart';
import '../controllers/focus_controller.dart';
import 'schedule_editor.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  final _taskController = TextEditingController();
  int _minutes = 25;
  bool _starting = false;
  List<String> _blocked = const [];

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    await ref.read(focusControllerProvider.notifier).start(
          task: _taskController.text,
          minutes: _minutes,
          blockedApps: _blocked,
        );
    if (mounted) {
      setState(() => _starting = false);
      final error = ref.read(focusControllerProvider).blockError;
      if (error != null) {
        showMessage(context, error, error: true);
      }
    }
  }

  Future<void> _pickApps() async {
    final picked = await showAppPicker(
      context,
      selected: _blocked,
      subtitle: 'These stay closed until the session ends.',
    );
    if (picked == null || !mounted) return;
    setState(() => _blocked = picked);
  }

  Future<void> _end() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'End this session?',
      message: 'The time so far will not be recorded in your history.',
      confirmLabel: 'End session',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(focusControllerProvider.notifier).cancel();
    if (mounted) showMessage(context, 'Session ended.');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final focus = ref.watch(focusControllerProvider);
    final sessions = ref.watch(focusSessionsProvider);
    final schedules = ref.watch(scheduleItemsProvider);
    final now = DateTime.now();
    final weekSessions = sessions
        .where((session) =>
            session.completed &&
            session.startedAt.isAfter(now.subtract(const Duration(days: 7))))
        .toList();

    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Focus',
            subtitle:
                'One task at a time. The timer keeps running if you leave this screen.',
            action: focus.run == null
                ? null
                : StatusPill(
                    label: focus.run!.paused ? 'Paused' : 'In session',
                    tone: PillTone.brass,
                    icon: Icons.hourglass_empty_rounded,
                  ),
          ),
          const SizedBox(height: 26),
          if (focus.completedSession != null) ...[
            _CompletionCard(
              session: focus.completedSession!,
              onDismiss: () => ref
                  .read(focusControllerProvider.notifier)
                  .acknowledgeCompletion(),
            ),
            const SizedBox(height: 16),
          ],
          if (focus.run != null) ...[
            if (focus.blockError != null) ...[
              _BlockErrorBanner(message: focus.blockError!),
              const SizedBox(height: 12),
            ],
            _ActiveTimer(
              focus: focus,
              onPause: () => ref.read(focusControllerProvider.notifier).pause(),
              onResume: () =>
                  ref.read(focusControllerProvider.notifier).resume(),
              onEnd: _end,
            )
          ] else
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconBadge(
                        icon: Icons.play_arrow_rounded,
                        size: 38,
                        color: palette.tealSoft,
                        iconColor: palette.teal,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Begin a session',
                                style: textTheme.titleLarge),
                            const SizedBox(height: 2),
                            Text(
                              'Pick a length and name the one thing that matters.',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: palette.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _taskController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _start(),
                    decoration: const InputDecoration(
                      hintText: 'What are you working on?',
                      prefixIcon: Icon(Icons.edit_outlined, size: 19),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BlockAppsRow(selected: _blocked, onTap: _pickApps),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final durations = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final minutes in [15, 25, 45, 60])
                            ChoiceChip(
                              label: Text('$minutes min'),
                              selected: _minutes == minutes,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _minutes = minutes),
                            ),
                        ],
                      );
                      final button = FilledButton.icon(
                        onPressed: _starting ? null : _start,
                        icon: _starting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 19),
                        label: Text(_starting ? 'Starting…' : 'Start focus'),
                      );
                      if (constraints.maxWidth < 560) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            durations,
                            const SizedBox(height: 14),
                            button,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: durations),
                          const SizedBox(width: 18),
                          button,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.offline_bolt_outlined,
                          size: 13, color: palette.muted),
                      const SizedBox(width: 6),
                      Text(
                        'The timer runs locally, even with no connection.',
                        style:
                            textTheme.bodySmall?.copyWith(color: palette.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final week = _WeekCard(sessions: weekSessions, now: now);
              final windows = _FocusWindowsCard(schedules: schedules);
              if (constraints.maxWidth < 880) {
                return Column(
                  children: [
                    week,
                    const SizedBox(height: 16),
                    windows,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: week),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: windows),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _HistoryCard(sessions: sessions),
        ],
      ),
    );
  }
}

class _BlockAppsRow extends StatelessWidget {
  const _BlockAppsRow({required this.selected, required this.onTap});

  final List<String> selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          children: [
            Icon(
              Icons.block_rounded,
              size: 18,
              color: selected.isEmpty ? palette.muted : palette.teal,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.isEmpty
                        ? 'Block apps while you focus'
                        : '${selected.length} app${selected.length == 1 ? '' : 's'} blocked',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selected.isEmpty
                        ? 'Nothing is blocked yet — tap to choose.'
                        : selected.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall
                        ?.copyWith(color: palette.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: palette.muted),
          ],
        ),
      ),
    );
  }
}

class _BlockErrorBanner extends StatelessWidget {
  const _BlockErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: palette.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: palette.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(
                color: palette.ink,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveTimer extends StatelessWidget {
  const _ActiveTimer({
    required this.focus,
    required this.onPause,
    required this.onResume,
    required this.onEnd,
  });

  final FocusState focus;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final run = focus.run!;
    final remaining = focus.remainingSeconds;
    final total = run.minutes * 60;
    final progress =
        total == 0 ? 0.0 : (1 - remaining / total).clamp(0.0, 1.0).toDouble();
    final mm = (remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (remaining % 60).toString().padLeft(2, '0');

    return PaperCard(
      borderColor: palette.brass.withValues(alpha: 0.45),
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(
                icon: run.paused
                    ? Icons.pause_rounded
                    : Icons.hourglass_empty_rounded,
                size: 38,
                color: palette.brassSoft,
                iconColor: palette.brass,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(run.paused ? 'Paused' : 'In session',
                        style: textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      run.task,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          textTheme.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: '${run.minutes} min',
                tone: PillTone.brass,
              ),
            ],
          ),
          const SizedBox(height: 24),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$mm:$ss',
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: context.isCompact ? 74 : 92,
                fontWeight: FontWeight.w500,
                height: 0.95,
                letterSpacing: -2,
                color: palette.ink,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            run.paused ? 'The clock is resting.' : 'Stay with it.',
            style: textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: palette.line,
              color: palette.brass,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: run.paused ? onResume : onPause,
                  icon: Icon(
                    run.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 19,
                  ),
                  label: Text(run.paused ? 'Resume' : 'Pause'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                style:
                    OutlinedButton.styleFrom(foregroundColor: palette.danger),
                onPressed: onEnd,
                child: const Text('End'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.session, required this.onDismiss});

  final FocusSession session;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
      decoration: BoxDecoration(
        color: palette.brassSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.brass.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          IconBadge(
            icon: Icons.check_rounded,
            size: 42,
            color: palette.surface,
            iconColor: palette.brass,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session complete', style: textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  '${session.minutes} minutes on “${session.task}”.',
                  style: textTheme.bodySmall?.copyWith(color: palette.ink),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onDismiss, child: const Text('Done')),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.sessions, required this.now});

  final List<FocusSession> sessions;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final days = List.generate(
      7,
      (index) => DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - index)),
    );
    final minutesByDay = <DateTime, int>{
      for (final day in days) day: 0,
    };
    for (final session in sessions) {
      final day = DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      );
      if (minutesByDay.containsKey(day)) {
        minutesByDay[day] = minutesByDay[day]! + session.minutes;
      }
    }
    final total = minutesByDay.values.fold<int>(0, (sum, value) => sum + value);
    final maxMinutes = minutesByDay.values.fold<int>(1, (max, value) {
      return value > max ? value : max;
    });
    final longest = sessions.fold<int>(
      0,
      (max, session) => session.minutes > max ? session.minutes : max,
    );

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('This week', style: textTheme.titleLarge),
              const Spacer(),
              Text(
                '$total min',
                style: textTheme.titleSmall?.copyWith(color: palette.brass),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 82,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${minutesByDay[day]}',
                            style: textTheme.labelSmall?.copyWith(
                              color: minutesByDay[day] == 0
                                  ? palette.line
                                  : palette.muted,
                              fontSize: 9,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 8 +
                                (minutesByDay[day]! / maxMinutes) *
                                    (day == days.last ? 56 : 48),
                            decoration: BoxDecoration(
                              color: minutesByDay[day] == 0
                                  ? palette.line
                                  : day == days.last
                                      ? palette.brass
                                      : palette.teal,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat('E').format(day).substring(0, 1),
                      style: textTheme.labelSmall?.copyWith(
                        color: day == days.last ? palette.ink : palette.muted,
                        fontWeight: day == days.last
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: palette.line),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Sessions',
                  value: '${sessions.length}',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Longest',
                  value: '${longest}m',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Average',
                  value: sessions.isEmpty
                      ? '—'
                      : '${(total / sessions.length).round()}m',
                ),
              ),
            ],
          ),
          if (sessions.isEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'No sessions yet. The first one is the hardest.',
              style: textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

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
        const SizedBox(height: 2),
        Text(value, style: textTheme.titleMedium),
      ],
    );
  }
}

class _FocusWindowsCard extends ConsumerWidget {
  const _FocusWindowsCard({required this.schedules});

  final List<FocusSchedule> schedules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Focus windows', style: textTheme.titleLarge),
              ),
              IconButton(
                onPressed: () => showScheduleEditor(context, ref),
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Add a focus window',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Recurring quiet hours that you can protect.',
            style: textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 12),
          if (schedules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No windows yet. Add one for the hours you want to keep clear.',
                    style: textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => showScheduleEditor(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Add a window'),
                  ),
                ],
              ),
            )
          else
            for (var index = 0; index < schedules.length; index++) ...[
              _ScheduleRow(schedule: schedules[index]),
              if (index < schedules.length - 1)
                Divider(height: 1, color: palette.line),
            ],
        ],
      ),
    );
  }
}

class _ScheduleRow extends ConsumerWidget {
  const _ScheduleRow({required this.schedule});

  final FocusSchedule schedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    return Opacity(
      opacity: schedule.enabled ? 1 : 0.55,
      child: InkWell(
        onTap: () => showScheduleEditor(context, ref, item: schedule),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                  color: schedule.enabled ? palette.brass : palette.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${schedule.timeRange} · ${_daysLabel(schedule.days)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          textTheme.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: schedule.enabled,
                onChanged: (_) =>
                    ref.read(dataActionsProvider).toggleSchedule(schedule),
              ),
              PopupMenuButton<String>(
                tooltip: 'Window actions',
                onSelected: (value) async {
                  if (value == 'edit') {
                    await showScheduleEditor(context, ref, item: schedule);
                  } else if (value == 'delete') {
                    final confirmed = await showConfirmDialog(
                      context: context,
                      title: 'Delete this window?',
                      message:
                          '“${schedule.label}” will be removed from your focus schedule.',
                      confirmLabel: 'Delete',
                      destructive: true,
                    );
                    if (confirmed) {
                      await ref
                          .read(dataActionsProvider)
                          .deleteSchedule(schedule.id);
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
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

  String _daysLabel(Set<int> days) {
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && days.containsAll(const {1, 2, 3, 4, 5})) {
      return 'Weekdays';
    }
    if (days.length == 2 && days.containsAll(const {6, 7})) {
      return 'Weekends';
    }
    const labels = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    final ordered = days.toList()..sort();
    return ordered.map((day) => labels[day]).join(', ');
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.sessions});

  final List<FocusSession> sessions;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final recent = sessions.take(8).toList();
    return PaperCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
            child: Row(
              children: [
                Text('Recent sessions', style: textTheme.titleLarge),
                const Spacer(),
                Text(
                  sessions.isEmpty ? '' : '${sessions.length} total',
                  style: textTheme.bodySmall?.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.line),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
              child: Text(
                'Finished sessions will appear here, with the task and the time you gave it.',
                style: textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                  height: 1.5,
                ),
              ),
            )
          else
            for (var index = 0; index < recent.length; index++) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 13, 18, 13),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: palette.success,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recent[index].task,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatShortDate(recent[index].startedAt),
                            style: textTheme.bodySmall
                                ?.copyWith(color: palette.muted),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(
                      label: '${recent[index].minutes} min',
                      tone: PillTone.neutral,
                    ),
                  ],
                ),
              ),
              if (index < recent.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: Divider(height: 1, color: palette.line),
                ),
            ],
        ],
      ),
    );
  }
}
