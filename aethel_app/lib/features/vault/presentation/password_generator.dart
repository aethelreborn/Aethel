import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/password_tools.dart';
import '../../../widgets/sheets.dart';

Future<String?> showPasswordGenerator(
  BuildContext context, {
  String initial = '',
}) {
  return showAethelSheet<String>(
    context: context,
    builder: (sheetContext) => _PasswordGenerator(initial: initial),
  );
}

class _PasswordGenerator extends StatefulWidget {
  const _PasswordGenerator({required this.initial});

  final String initial;

  @override
  State<_PasswordGenerator> createState() => _PasswordGeneratorState();
}

class _PasswordGeneratorState extends State<_PasswordGenerator> {
  late int _length;
  bool _uppercase = true;
  bool _lowercase = true;
  bool _numbers = true;
  bool _symbols = true;
  late String _value;

  @override
  void initState() {
    super.initState();
    _length = widget.initial.isEmpty ? 20 : widget.initial.length.clamp(8, 64);
    _value = widget.initial.isEmpty ? _generate() : widget.initial;
  }

  String _generate() {
    return generatePassword(
      length: _length,
      uppercase: _uppercase,
      lowercase: _lowercase,
      numbers: _numbers,
      symbols: _symbols,
    );
  }

  void _regenerate() {
    setState(() => _value = _generate());
  }

  void _toggle(void Function() change) {
    setState(() {
      change();
      _value = _generate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final strength = passwordStrength(_value);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: 'Generate a password',
            subtitle: 'Created on this device. Nothing is sent anywhere.',
            trailing: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                  decoration: BoxDecoration(
                    color: palette.ground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        _value,
                        style: textTheme.titleMedium?.copyWith(
                          fontFamily: 'Manrope',
                          letterSpacing: 0.6,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              passwordStrengthLabel(strength),
                              style: textTheme.bodySmall?.copyWith(
                                color: strength >= 3
                                    ? palette.success
                                    : strength == 2
                                        ? palette.brass
                                        : palette.danger,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: _value),
                              );
                              if (context.mounted) {
                                showMessage(context, 'Password copied.');
                              }
                            },
                            icon: const Icon(Icons.copy_rounded, size: 19),
                            tooltip: 'Copy',
                          ),
                          IconButton(
                            onPressed: _regenerate,
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            tooltip: 'Generate another',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Text('Length', style: textTheme.titleSmall),
                    const Spacer(),
                    Text(
                      '$_length',
                      style:
                          textTheme.titleSmall?.copyWith(color: palette.teal),
                    ),
                  ],
                ),
                Slider(
                  value: _length.toDouble(),
                  min: 8,
                  max: 64,
                  divisions: 56,
                  label: '$_length',
                  onChanged: (value) {
                    setState(() {
                      _length = value.round();
                      _value = _generate();
                    });
                  },
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ToggleChip(
                      label: 'A–Z',
                      selected: _uppercase,
                      onSelected: () => _toggle(() => _uppercase = !_uppercase),
                    ),
                    _ToggleChip(
                      label: 'a–z',
                      selected: _lowercase,
                      onSelected: () => _toggle(() => _lowercase = !_lowercase),
                    ),
                    _ToggleChip(
                      label: '0–9',
                      selected: _numbers,
                      onSelected: () => _toggle(() => _numbers = !_numbers),
                    ),
                    _ToggleChip(
                      label: '!@#',
                      selected: _symbols,
                      onSelected: () => _toggle(() => _symbols = !_symbols),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_value),
                    child: const Text('Use this password'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }
}
