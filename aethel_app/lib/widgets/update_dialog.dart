import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_providers.dart';
import '../core/theme/app_theme.dart';
import '../core/update/update_service.dart';
import 'page.dart';
import 'sheets.dart';

enum UpdatePrompt { upToDate, declined, shown }

/// Checks GitHub Releases for a newer build and, when there is one, offers
/// it. With [force] (the Settings row) it ignores the throttle and tells the
/// user either way.
Future<UpdatePrompt> promptUpdateIfAvailable(
  BuildContext context,
  WidgetRef ref, {
  bool force = false,
}) async {
  final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
  final info = await UpdateService.instance.check(prefs, force: force);
  if (!context.mounted) return UpdatePrompt.upToDate;
  if (info == null) {
    if (force) {
      showMessage(context, 'Aethel is up to date.');
    }
    return UpdatePrompt.upToDate;
  }
  await showAethelSheet<void>(
    context: context,
    builder: (_) => UpdateSheet(info: info, prefs: prefs),
  );
  return UpdatePrompt.shown;
}

class UpdateSheet extends StatefulWidget {
  const UpdateSheet({super.key, required this.info, required this.prefs});

  final UpdateInfo info;
  final SharedPreferences prefs;

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<UpdateSheet> {
  double? _progress;
  bool _busy = false;
  String? _error;

  UpdateInfo get _info => widget.info;

  Future<void> _later() async {
    await UpdateService.instance.snooze(widget.prefs, _info);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _update() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    final outcome = await UpdateService.instance.install(
      _info,
      onProgress: (value) {
        if (mounted) setState(() => _progress = value);
      },
    );
    if (!mounted) return;
    switch (outcome) {
      case UpdateOutcome.installed:
        showMessage(context, 'Follow the prompt to finish installing.');
        Navigator.of(context).pop();
      case UpdateOutcome.opened:
        showMessage(context, 'Opened the ${_info.tag} release.');
        Navigator.of(context).pop();
      case UpdateOutcome.relaunched:
        break;
      case UpdateOutcome.failed:
        setState(() {
          _busy = false;
          _progress = null;
          _error = 'The download did not finish. Try again in a moment.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final notes =
        _info.notes.split('\n').where((line) => line.trim().isNotEmpty);
    final percent = _progress == null ? null : '${(_progress! * 100).round()}%';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              title: 'Aethel ${_info.version} is ready',
              subtitle: 'A newer build is waiting on GitHub Releases.',
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.ground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in notes.take(7))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 7, right: 9),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: palette.teal,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              line
                                  .trim()
                                  .replaceFirst(RegExp(r'^[-*•]\s*'), ''),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              ErrorBanner(message: _error!),
            ],
            if (_busy && _progress != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: _progress),
              ),
              const SizedBox(height: 6),
              Text(
                _progress! >= 1
                    ? 'Handing over to the installer…'
                    : 'Downloading $percent',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: palette.muted),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _update,
                    icon: const Icon(Icons.system_update_rounded, size: 18),
                    label: Text(_busy ? 'Working…' : 'Update now'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _busy ? null : _later,
                  child: const Text('Later'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
