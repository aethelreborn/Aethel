import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/platform/permission_catalog.dart';
import '../core/theme/app_theme.dart';
import 'page.dart';
import 'sheets.dart';

/// SharedPreferences flag: the first-run explanation has been shown once.
const kPermissionCoachSeen = 'permission_coach_seen';

/// Explains the two platform permissions Aethel needs, once per install.
/// Does nothing on platforms that have nothing to grant.
Future<void> showPermissionCoachOnce(
  BuildContext context,
  SharedPreferences prefs,
) async {
  if (prefs.getBool(kPermissionCoachSeen) ?? false) return;
  final entries = await PermissionCatalog.load();
  if (!entries.any((entry) => entry.needsAction)) {
    await prefs.setBool(kPermissionCoachSeen, true);
    return;
  }
  if (!context.mounted) return;
  try {
    await showAethelSheet<void>(
      context: context,
      builder: (_) => PermissionCoachSheet(initial: entries),
    );
  } finally {
    // Whatever the user did — granted, skipped, or dismissed — do not nag.
    await prefs.setBool(kPermissionCoachSeen, true);
  }
}

class PermissionCoachSheet extends StatefulWidget {
  const PermissionCoachSheet({super.key, required this.initial});

  final List<PermissionEntry> initial;

  @override
  State<PermissionCoachSheet> createState() => _PermissionCoachSheetState();
}

class _PermissionCoachSheetState extends State<PermissionCoachSheet>
    with WidgetsBindingObserver {
  late List<PermissionEntry> _entries = widget.initial;
  bool _busy = false;

  bool get _pending => _entries.any((entry) => entry.needsAction);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from a system settings screen — read whatever they changed.
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    final entries = await PermissionCatalog.load();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  Future<void> _grantAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    var entries = _entries;
    for (final entry in entries.where((entry) => entry.needsAction)) {
      entries = await PermissionCatalog.request(entry);
      if (!mounted) return;
      setState(() => _entries = entries);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _grantOne(PermissionEntry entry) async {
    if (_busy) return;
    setState(() => _busy = true);
    final entries = await PermissionCatalog.request(entry);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        _entries.where((entry) => entry.stage != PermissionStage.unavailable);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader(
              title: 'Aethel needs two things',
              subtitle:
                  'Asked once, on this device. Nothing leaves your vault.',
            ),
            const SizedBox(height: 10),
            for (final entry in visible) ...[
              _PermissionRow(
                entry: entry,
                busy: _busy,
                onAct: () => _grantOne(entry),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : (_pending
                            ? _grantAll
                            : () => Navigator.of(context).pop()),
                    child: Text(_pending ? 'Grant access' : 'Done'),
                  ),
                ),
                if (_pending) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Later'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.entry,
    required this.busy,
    required this.onAct,
  });

  final PermissionEntry entry;
  final bool busy;
  final VoidCallback onAct;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final granted = entry.stage == PermissionStage.granted ||
        entry.stage == PermissionStage.notNeeded;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: palette.ground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            entry.key == 'reminders'
                ? Icons.notifications_none_rounded
                : Icons.apps_outlined,
            size: 20,
            color: granted ? palette.teal : palette.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  entry.detail,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (granted)
            const StatusPill(
              label: 'On',
              tone: PillTone.teal,
              icon: Icons.check_rounded,
            )
          else
            TextButton(
              onPressed: busy ? null : onAct,
              child: Text(entry.stage == PermissionStage.blocked
                  ? 'Settings'
                  : 'Allow'),
            ),
        ],
      ),
    );
  }
}
