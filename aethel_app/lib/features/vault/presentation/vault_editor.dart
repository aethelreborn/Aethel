import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/data_actions.dart';
import '../../../data/models.dart';
import '../../../widgets/page.dart';
import '../../../widgets/sheets.dart';
import 'password_generator.dart';

Future<VaultItem?> showVaultEditor(
  BuildContext context,
  WidgetRef ref, {
  VaultItem? item,
  VaultType initialType = VaultType.password,
}) {
  return showAethelSheet<VaultItem>(
    context: context,
    builder: (sheetContext) => _VaultEditorSheet(
      actions: ref.read(dataActionsProvider),
      item: item,
      initialType: initialType,
    ),
  );
}

class _VaultEditorSheet extends StatefulWidget {
  const _VaultEditorSheet({
    required this.actions,
    required this.initialType,
    this.item,
  });

  final DataActions actions;
  final VaultItem? item;
  final VaultType initialType;

  @override
  State<_VaultEditorSheet> createState() => _VaultEditorSheetState();
}

class _VaultEditorSheetState extends State<_VaultEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _url;
  late final TextEditingController _notes;
  late final TextEditingController _cardNumber;
  late final TextEditingController _cardholder;
  late final TextEditingController _expiry;
  late final TextEditingController _cvv;
  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;

  late VaultType _type;
  late bool _favorite;
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _type = item?.type ?? widget.initialType;
    _favorite = item?.favorite ?? false;
    _title = TextEditingController(text: item?.title ?? '');
    _username = TextEditingController(text: item?.username ?? '');
    _password = TextEditingController(text: item?.password ?? '');
    _url = TextEditingController(text: item?.url ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
    _cardNumber = TextEditingController(text: item?.cardNumber ?? '');
    _cardholder = TextEditingController(text: item?.cardholder ?? '');
    _expiry = TextEditingController(text: item?.expiry ?? '');
    _cvv = TextEditingController(text: item?.cvv ?? '');
    _fullName = TextEditingController(text: item?.fullName ?? '');
    _email = TextEditingController(text: item?.email ?? '');
    _phone = TextEditingController(text: item?.phone ?? '');
    _address = TextEditingController(text: item?.address ?? '');
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _username,
      _password,
      _url,
      _notes,
      _cardNumber,
      _cardholder,
      _expiry,
      _cvv,
      _fullName,
      _email,
      _phone,
      _address,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final existing = widget.item;
    final item = VaultItem(
      id: existing?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      type: _type,
      username: _username.text.trim(),
      password: _password.text,
      url: _url.text.trim(),
      notes: _notes.text.trim(),
      cardNumber: _cardNumber.text.replaceAll(RegExp(r'\s'), ''),
      cardholder: _cardholder.text.trim(),
      expiry: _expiry.text.trim(),
      cvv: _cvv.text.trim(),
      fullName: _fullName.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      favorite: _favorite,
      pending: true,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      final saved = await widget.actions.saveVault(item);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this entry. $error';
      });
    }
  }

  Future<void> _generate() async {
    final value = await showPasswordGenerator(
      context,
      initial: _password.text,
    );
    if (value != null && mounted) {
      setState(() {
        _password.text = value;
        _obscure = false;
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
          title: editing ? 'Edit entry' : 'New entry',
          subtitle: 'Encrypted on this device before it is synced.',
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
                  const FieldLabel('Kind'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in VaultType.values)
                        ChoiceChip(
                          label: Text(type.label),
                          selected: _type == type,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _type = type),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const FieldLabel('Title'),
                  TextFormField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Personal email',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Give this entry a title.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  ..._fieldsForType(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                    decoration: BoxDecoration(
                      color: palette.ground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.line),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star_outline_rounded,
                            size: 19, color: palette.brass),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pin to the top of the vault',
                            style: textTheme.bodyMedium,
                          ),
                        ),
                        Switch(
                          value: _favorite,
                          onChanged: (value) =>
                              setState(() => _favorite = value),
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
                  : Text(editing ? 'Save changes' : 'Seal this entry'),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _fieldsForType() {
    switch (_type) {
      case VaultType.password:
        return [
          const FieldLabel('Username or email'),
          TextFormField(
            controller: _username,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'name@example.com'),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Password'),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'Your secret',
              suffixIconConstraints:
                  const BoxConstraints(maxWidth: 102, minWidth: 76),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 19,
                    ),
                    tooltip: _obscure ? 'Reveal' : 'Hide',
                  ),
                  IconButton(
                    onPressed: _generate,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    tooltip: 'Generate password',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Website'),
          TextFormField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'https://…'),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Notes', hint: 'Optional'),
          TextFormField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration:
                const InputDecoration(hintText: 'Anything else to remember'),
          ),
        ];
      case VaultType.card:
        return [
          const FieldLabel('Name on card'),
          TextFormField(
            controller: _cardholder,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration:
                const InputDecoration(hintText: 'As printed on the card'),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Card number'),
          TextFormField(
            controller: _cardNumber,
            keyboardType: TextInputType.number,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
              LengthLimitingTextInputFormatter(23),
            ],
            decoration: const InputDecoration(hintText: '0000 0000 0000 0000'),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Expiry'),
                    TextFormField(
                      controller: _expiry,
                      keyboardType: TextInputType.datetime,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                        LengthLimitingTextInputFormatter(5),
                      ],
                      decoration: const InputDecoration(hintText: 'MM/YY'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('CVV'),
                    TextFormField(
                      controller: _cvv,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(hintText: '123'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const FieldLabel('Notes', hint: 'Optional'),
          TextFormField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                hintText: 'Billing address, PIN, or a reminder'),
          ),
        ];
      case VaultType.identity:
        return [
          const FieldLabel('Full name'),
          TextFormField(
            controller: _fullName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Legal name'),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Email'),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'name@example.com'),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Phone'),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: '+1 555 000 0000'),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Address'),
          TextFormField(
            controller: _address,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.words,
            decoration:
                const InputDecoration(hintText: 'Street, city, postal code'),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Notes', hint: 'Optional'),
          TextFormField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                hintText: 'Passport number, ID details, anything else'),
          ),
        ];
      case VaultType.note:
      case VaultType.secureNote:
        return [
          const FieldLabel('Note'),
          TextFormField(
            controller: _notes,
            minLines: 7,
            maxLines: 14,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Write freely. This stays sealed.',
              alignLabelWithHint: true,
            ),
          ),
        ];
    }
  }
}
