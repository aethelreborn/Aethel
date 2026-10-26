import 'package:flutter/material.dart';

import '../core/platform/device_services.dart';
import '../core/theme/app_theme.dart';
import 'page.dart';
import 'sheets.dart';

/// Opens a sheet with every application this device can launch, so the user
/// picks from the real list instead of typing names by hand.
///
/// Returns the chosen names, `null` when the sheet is dismissed.
Future<List<String>?> showAppPicker(
  BuildContext context, {
  required List<String> selected,
  String title = 'Block apps',
  String subtitle = 'Pick what should stay closed during focus.',
}) {
  return showAethelSheet<List<String>>(
    context: context,
    builder: (sheetContext) => _AppPickerSheet(
      title: title,
      subtitle: subtitle,
      selected: selected,
    ),
  );
}

class _AppPickerSheet extends StatefulWidget {
  const _AppPickerSheet({
    required this.title,
    required this.subtitle,
    required this.selected,
  });

  final String title;
  final String subtitle;
  final List<String> selected;

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  final _search = TextEditingController();
  final _manual = TextEditingController();

  bool _loading = true;
  bool _canList = false;
  String? _error;
  List<InstalledApp> _apps = const [];
  late final Set<String> _picked = widget.selected.toSet();

  @override
  void initState() {
    super.initState();
    _manual.text = widget.selected.join(', ');
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final capabilities = await DeviceServices.instance.capabilities();
    if (!capabilities.appList) {
      if (mounted) {
        setState(() {
          _loading = false;
          _canList = false;
        });
      }
      return;
    }
    try {
      final apps = await DeviceServices.instance.installedApps();
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _canList = apps.isNotEmpty;
        _loading = false;
        if (apps.isEmpty) {
          _error = 'No applications could be read on this device.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _canList = false;
        _error = 'Could not read the installed applications.';
      });
    }
  }

  List<InstalledApp> get _filtered {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _apps;
    return _apps
        .where((app) => app.name.toLowerCase().contains(query))
        .toList();
  }

  void _toggle(InstalledApp app) {
    setState(() {
      if (!_picked.remove(app.name)) _picked.add(app.name);
    });
  }

  void _submit() {
    if (_canList) {
      Navigator.of(context).pop(_picked.toList()..sort());
      return;
    }
    final names = _manual.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    Navigator.of(context).pop(names);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          title: widget.title,
          subtitle: widget.subtitle,
          trailing: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
          ),
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: !_canList
                ? _fallback(textTheme, palette)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search apps',
                          prefixIcon:
                              const Icon(Icons.search_rounded, size: 19),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  icon:
                                      const Icon(Icons.close_rounded, size: 17),
                                  onPressed: () {
                                    _search.clear();
                                    setState(() {});
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 34),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else ...[
                        if (_error != null)
                          ErrorBanner(
                            message: _error!,
                            onDismiss: () => setState(() => _error = null),
                          ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: _filtered.isEmpty
                              ? Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 26),
                                  child: Text(
                                    'No apps match “${_search.text.trim()}”.',
                                    style: textTheme.bodySmall
                                        ?.copyWith(color: palette.muted),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _filtered.length,
                                  itemBuilder: (context, index) {
                                    final app = _filtered[index];
                                    final checked = _picked.contains(app.name);
                                    return InkWell(
                                      onTap: () => _toggle(app),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        child: Row(
                                          children: [
                                            Icon(
                                              checked
                                                  ? Icons.check_circle_rounded
                                                  : Icons.circle_outlined,
                                              size: 21,
                                              color: checked
                                                  ? palette.teal
                                                  : palette.line,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                app.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: textTheme.bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ],
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
              onPressed: _loading ? null : _submit,
              child: Text(_canList
                  ? _picked.isEmpty
                      ? 'Done — nothing selected'
                      : 'Done · ${_picked.length} selected'
                  : 'Use these apps'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallback(TextTheme textTheme, AethelColors palette) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: palette.ground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.line),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 19, color: palette.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This system does not expose an application list, so type '
                    'the names you want on the block list.',
                    style: textTheme.bodySmall
                        ?.copyWith(color: palette.muted, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _manual,
            textCapitalization: TextCapitalization.none,
            decoration: const InputDecoration(
              hintText: 'Instagram, X, YouTube',
            ),
          ),
        ],
      ),
    );
  }
}
