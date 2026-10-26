import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/data_actions.dart';
import '../../../data/models.dart';
import '../../../widgets/app_picker.dart';
import '../../../widgets/page.dart';
import '../../../widgets/sheets.dart';

Future<FocusSchedule?> showScheduleEditor(
  BuildContext context,
  WidgetRef ref, {
  FocusSchedule? item,
}) {
  return showAethelSheet<FocusSchedule>(
    context: context,
    builder: (sheetContext) => _ScheduleEditorSheet(
      actions: ref.read(dataActionsProvider),
      item: item,
    ),
  );
}

class _ScheduleEditorSheet extends StatefulWidget {
  const _ScheduleEditorSheet({required this.actions, this.item});

  final DataActions actions;
  final FocusSchedule? item;

  @override
  State<_ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<_ScheduleEditorSheet> {
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late List<String> _blocked;
  late int _start;
  late int _end;
  late Set<int> _days;
  late bool _enabled;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _label = TextEditingController(text: item?.label ?? '');
    _blocked = List<String>.of(item?.blockedApps ?? const []);
    _start = item?.startMinutes ?? 9 * 60;
    _end = item?.endMinutes ?? 11 * 60;
    _days = item?.days.toSet() ?? {1, 2, 3, 4, 5};
    _enabled = item?.enabled ?? true;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  String _timeLabel(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final suffix = hour >= 12 ? 'pm' : 'am';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')}$suffix';
  }

  Future<void> _pickTime({required bool start}) async {
    final minutes = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: start ? 'When should focus begin?' : 'When should it end?',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked.hour * 60 + picked.minute;
      } else {
        _end = picked.hour * 60 + picked.minute;
      }
    });
  }

  Future<void> _pickApps() async {
    final picked = await showAppPicker(
      context,
      selected: _blocked,
      subtitle: 'Closed for the whole window, on every one of its days.',
    );
    if (picked == null || !mounted) return;
    setState(() => _blocked = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_days.isEmpty) {
      setState(() => _error = 'Pick at least one day for this window.');
      return;
    }
    if (_end <= _start) {
      setState(() => _error = 'The end time needs to be after the start time.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final existing = widget.item;
    final schedule = FocusSchedule(
      id: existing?.id ?? const Uuid().v4(),
      label: _label.text.trim(),
      startMinutes: _start,
      endMinutes: _end,
      days: _days,
      blockedApps: _blocked,
      enabled: _enabled,
      pending: true,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      final saved = await widget.actions.saveSchedule(schedule);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this focus window. $error';
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
          title: editing ? 'Edit focus window' : 'New focus window',
          subtitle: 'A recurring block of time when the world can wait.',
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
                  const FieldLabel('Name'),
                  TextFormField(
                    controller: _label,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Morning deep work',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Give this window a name.'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  const FieldLabel('Window'),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeButton(
                          label: 'Starts',
                          value: _timeLabel(_start),
                          onTap: () => _pickTime(start: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TimeButton(
                          label: 'Ends',
                          value: _timeLabel(_end),
                          onTap: () => _pickTime(start: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const FieldLabel('Days'),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        FilterChip(
                          label: Text(_dayLabels[day - 1]),
                          selected: _days.contains(day),
                          showCheckmark: false,
                          onSelected: (_) => setState(() {
                            if (_days.contains(day)) {
                              _days.remove(day);
                            } else {
                              _days.add(day);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const FieldLabel(
                    'Blocked apps',
                    hint: 'Optional, choose from this device',
                  ),
                  _AppsField(
                    selected: _blocked,
                    onTap: _pickApps,
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
                          Icons.hourglass_empty_rounded,
                          size: 20,
                          color: _enabled ? palette.brass : palette.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Keep this window active',
                            style: textTheme.bodyMedium,
                          ),
                        ),
                        Switch(
                          value: _enabled,
                          onChanged: (value) =>
                              setState(() => _enabled = value),
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
                  : Text(editing ? 'Save changes' : 'Add focus window'),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppsField extends StatelessWidget {
  const _AppsField({required this.selected, required this.onTap});

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
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.block_rounded,
                  size: 18,
                  color: selected.isEmpty ? palette.muted : palette.teal,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selected.isEmpty
                        ? 'Nothing blocked yet — tap to choose apps'
                        : '${selected.length} app${selected.length == 1 ? '' : 's'} blocked',
                    style: textTheme.bodyMedium,
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: palette.muted),
              ],
            ),
            if (selected.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final name in selected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: palette.ground,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: palette.line),
                      ),
                      child: Text(
                        name,
                        style:
                            textTheme.labelSmall?.copyWith(color: palette.ink),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(value, style: textTheme.titleSmall),
                ),
                Icon(Icons.schedule_rounded, size: 17, color: palette.muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
