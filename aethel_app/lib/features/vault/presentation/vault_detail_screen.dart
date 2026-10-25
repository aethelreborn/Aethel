import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';
import '../../../widgets/page.dart';
import '../../../widgets/paper.dart';
import '../../../widgets/sheets.dart';
import '../../../widgets/vault_visuals.dart';
import 'vault_editor.dart';

void showVaultDetail(BuildContext context, VaultItem item) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VaultDetailScreen(item: item),
    ),
  );
}

class VaultDetailScreen extends ConsumerStatefulWidget {
  const VaultDetailScreen({super.key, required this.item});

  final VaultItem item;

  @override
  ConsumerState<VaultDetailScreen> createState() => _VaultDetailScreenState();
}

class _VaultDetailScreenState extends ConsumerState<VaultDetailScreen> {
  bool _removing = false;

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    showMessage(context, '$label copied.');
  }

  Future<void> _openUrl(String raw) async {
    var value = raw.trim();
    if (value.isEmpty) return;
    if (!value.contains('://')) value = 'https://$value';
    final uri = Uri.tryParse(value);
    if (uri == null) {
      showMessage(context, 'That website address is not valid.', error: true);
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showMessage(context, 'Could not open that website.', error: true);
    }
  }

  Future<void> _edit(VaultItem item) async {
    await showVaultEditor(context, ref, item: item);
  }

  Future<void> _delete(VaultItem item) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Delete this entry?',
      message:
          '“${item.title}” will be removed from this device and the synced vault. This cannot be undone.',
      confirmLabel: 'Delete entry',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _removing = true);
    await ref.read(dataActionsProvider).deleteVault(item.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _toggleFavorite(VaultItem item) async {
    await ref.read(dataActionsProvider).saveVault(
          item.copyWith(favorite: !item.favorite),
        );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final current = ref
            .watch(vaultItemsProvider)
            .firstWhereOrNull((entry) => entry.id == widget.item.id) ??
        widget.item;

    return Scaffold(
      body: LedgerBackground(
        child: SafeArea(
          child: _removing
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    context.isCompact ? 20 : 36,
                    10,
                    context.isCompact ? 20 : 36,
                    48,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                tooltip: 'Back to the vault',
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => _toggleFavorite(current),
                                icon: Icon(
                                  current.favorite
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color:
                                      current.favorite ? palette.brass : null,
                                ),
                                tooltip: current.favorite
                                    ? 'Remove from favourites'
                                    : 'Pin to favourites',
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'More actions',
                                onSelected: (value) {
                                  if (value == 'edit') _edit(current);
                                  if (value == 'delete') _delete(current);
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit entry'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Delete entry',
                                      style: TextStyle(color: palette.danger),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconBadge(
                                icon: vaultIcon(current.type),
                                size: 58,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      current.title,
                                      style: textTheme.headlineLarge,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      vaultTypeDescription(current.type),
                                      style: textTheme.bodyMedium
                                          ?.copyWith(color: palette.muted),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        StatusPill(
                                          label: current.type.label,
                                          tone: PillTone.teal,
                                        ),
                                        StatusPill(
                                          label: current.pending
                                              ? 'Waiting to sync'
                                              : 'Synced',
                                          tone: current.pending
                                              ? PillTone.brass
                                              : PillTone.neutral,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          _DetailCard(
                            title: switch (current.type) {
                              VaultType.password => 'Sign-in',
                              VaultType.card => 'Card details',
                              VaultType.identity => 'Identity',
                              VaultType.note || VaultType.secureNote => 'Note',
                            },
                            child: Column(
                              children: _detailRows(context, current),
                            ),
                          ),
                          if (current.notes.isNotEmpty &&
                              current.type != VaultType.note &&
                              current.type != VaultType.secureNote) ...[
                            const SizedBox(height: 14),
                            _DetailCard(
                              title: 'Notes',
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 16, 18, 20),
                                child: SelectableText(
                                  current.notes,
                                  style: textTheme.bodyMedium?.copyWith(
                                    height: 1.65,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _edit(current),
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 18),
                                  label: const Text('Edit entry'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: palette.danger,
                                ),
                                onPressed: () => _delete(current),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_outline_rounded,
                                  size: 13, color: palette.muted),
                              const SizedBox(width: 6),
                              Text(
                                'Sealed on this device before syncing.',
                                style: textTheme.bodySmall
                                    ?.copyWith(color: palette.muted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _detailRows(BuildContext context, VaultItem item) {
    final palette = context.aethel;
    final rows = <Widget>[];

    void add(Widget row, {bool divider = true}) {
      if (rows.isNotEmpty && divider) {
        rows.add(Divider(height: 1, color: palette.line));
      }
      rows.add(row);
    }

    switch (item.type) {
      case VaultType.password:
        if (item.username.isNotEmpty) {
          add(_FieldRow(
            icon: Icons.person_outline_rounded,
            label: 'Username',
            value: item.username,
            onCopy: () => _copy(item.username, 'Username'),
          ));
        }
        if (item.password.isNotEmpty) {
          add(_SecretRow(
            label: 'Password',
            value: item.password,
            onCopy: () => _copy(item.password, 'Password'),
          ));
        }
        if (item.url.isNotEmpty) {
          add(_FieldRow(
            icon: Icons.link_rounded,
            label: 'Website',
            value: item.url,
            onTap: () => _openUrl(item.url),
            trailing: IconButton(
              onPressed: () => _copy(item.url, 'Website'),
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: 'Copy website',
            ),
          ));
        }
        break;
      case VaultType.card:
        if (item.cardNumber.isNotEmpty) {
          add(_FieldRow(
            icon: Icons.credit_card_rounded,
            label: 'Card number',
            value: _groupCard(item.cardNumber),
            onCopy: () => _copy(item.cardNumber, 'Card number'),
          ));
        }
        if (item.cardholder.isNotEmpty) {
          add(_FieldRow(
            icon: Icons.person_outline_rounded,
            label: 'Name on card',
            value: item.cardholder,
            onCopy: () => _copy(item.cardholder, 'Cardholder name'),
          ));
        }
        if (item.expiry.isNotEmpty) {
          add(_FieldRow(
            icon: Icons.event_outlined,
            label: 'Expiry',
            value: item.expiry,
            onCopy: () => _copy(item.expiry, 'Expiry'),
          ));
        }
        if (item.cvv.isNotEmpty) {
          add(_SecretRow(
            label: 'CVV',
            value: item.cvv,
            onCopy: () => _copy(item.cvv, 'CVV'),
          ));
        }
        break;
      case VaultType.identity:
        if (item.fullName.isNotEmpty) {
          add(_FieldRow(
            icon: Icons.badge_outlined,
            label: 'Full name',
            value: item.fullName,
            onCopy: () => _copy(item.fullName, 'Name'),
          ));
        }
        if (item.email.isNotEmpty) {
          add(_FieldRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: item.email,
            onCopy: () => _copy(item.email, 'Email'),
          ));
        }
        if (item.phone.isNotEmpty) {
          add(_FieldRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: item.phone,
            onCopy: () => _copy(item.phone, 'Phone'),
          ));
        }
        if (item.address.isNotEmpty) {
          add(_FieldRow(
            icon: Icons.location_on_outlined,
            label: 'Address',
            value: item.address,
            onCopy: () => _copy(item.address, 'Address'),
          ));
        }
        break;
      case VaultType.note:
      case VaultType.secureNote:
        add(
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: SelectableText(
              item.notes.isEmpty ? 'This note is empty.' : item.notes,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.7,
                    color: item.notes.isEmpty ? palette.muted : palette.ink,
                  ),
            ),
          ),
        );
        break;
    }

    if (rows.isEmpty) {
      add(
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Text(
            'No details yet. Edit this entry to add some.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: palette.muted),
          ),
        ),
      );
    }

    return rows;
  }

  String _groupCard(String value) {
    final digits = value.replaceAll(RegExp(r'\s'), '');
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && index % 4 == 0) buffer.write(' ');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    return PaperCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: palette.muted,
                    letterSpacing: 0.8,
                  ),
            ),
          ),
          Divider(height: 1, color: palette.line),
          child,
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 13, 10, 13),
        child: Row(
          children: [
            Icon(icon, size: 19, color: palette.muted),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.labelSmall?.copyWith(color: palette.muted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onCopy != null)
              IconButton(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy $label',
              )
            else if (onTap != null)
              Icon(
                Icons.open_in_new_rounded,
                size: 17,
                color: palette.muted,
              ),
          ],
        ),
      ),
    );
  }
}

class _SecretRow extends StatefulWidget {
  const _SecretRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  State<_SecretRow> createState() => _SecretRowState();
}

class _SecretRowState extends State<_SecretRow> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final count = widget.value.length < 8
        ? 8
        : widget.value.length > 16
            ? 16
            : widget.value.length;
    final hidden = List.filled(count, '•').join();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 13, 10, 13),
      child: Row(
        children: [
          Icon(Icons.key_rounded, size: 19, color: palette.muted),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: textTheme.labelSmall?.copyWith(color: palette.muted),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  _visible ? widget.value : hidden,
                  style: textTheme.bodyMedium?.copyWith(
                    letterSpacing: _visible ? 0.2 : 1.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _visible = !_visible),
            icon: Icon(
              _visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 19,
            ),
            tooltip:
                _visible ? 'Hide ${widget.label}' : 'Reveal ${widget.label}',
          ),
          IconButton(
            onPressed: widget.onCopy,
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Copy ${widget.label}',
          ),
        ],
      ),
    );
  }
}
