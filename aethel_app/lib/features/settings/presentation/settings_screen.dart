import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app_providers.dart';
import '../../../core/network/sync_service.dart';
import '../../../core/platform/permission_catalog.dart';
import '../../../core/theme/app_theme.dart';
import '../../premium/premium_controller.dart';
import '../../premium/upgrade_sheet.dart';
import '../../../widgets/page.dart';
import '../../../widgets/password_strength.dart';
import '../../../widgets/paper.dart';
import '../../../widgets/sheets.dart';
import '../../../widgets/update_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final session = ref.watch(sessionControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final sync = ref.watch(syncStatusProvider).value;
    final premium = ref.watch(premiumControllerProvider);
    final profile = session.profile;
    final name = (profile?.name.trim().isNotEmpty ?? false)
        ? profile!.name.trim()
        : profile?.email.split('@').first ?? 'You';
    final email = profile?.email ?? '';
    final initial = name.isEmpty ? 'A' : name[0].toUpperCase();

    return PageBody(
      maxWidth: 900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Settings',
            subtitle: 'Your account, your key, your pace.',
            action: OutlinedButton.icon(
              onPressed: session.busy
                  ? null
                  : () => ref.read(sessionControllerProvider.notifier).lock(),
              icon: const Icon(Icons.lock_outline_rounded, size: 18),
              label: const Text('Lock now'),
            ),
          ),
          const SizedBox(height: 26),
          PaperCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.tealSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: palette.teal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: textTheme.headlineSmall),
                          const SizedBox(height: 3),
                          Text(
                            email,
                            style: textTheme.bodySmall
                                ?.copyWith(color: palette.muted),
                          ),
                          const SizedBox(height: 8),
                          const StatusPill(
                            label: 'Unlocked on this device',
                            tone: PillTone.teal,
                            icon: Icons.lock_open_rounded,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(height: 1, color: palette.line),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: session.busy
                            ? null
                            : () => ref
                                .read(sessionControllerProvider.notifier)
                                .lock(),
                        icon: const Icon(Icons.lock_outline_rounded, size: 17),
                        label: const Text('Lock'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton(
                        onPressed:
                            session.busy ? null : () => _signOut(context, ref),
                        child: Text(
                          'Sign out',
                          style: TextStyle(color: palette.danger),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Plan',
            children: [
              _Row(
                icon: Icons.workspace_premium_outlined,
                title: 'Aethel Premium',
                subtitle: _premiumLabel(premium),
                onTap: () => showUpgradeSheet(context),
                trailing:
                    Icon(Icons.chevron_right_rounded, color: palette.muted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Appearance',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.contrast_rounded,
                            size: 19, color: palette.muted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Theme', style: textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                'Warm paper by day, deep forest at night.',
                                style: textTheme.bodySmall
                                    ?.copyWith(color: palette.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (value) => ref
                          .read(settingsControllerProvider.notifier)
                          .setThemeMode(value.first),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Security',
            children: [
              _Row(
                icon: Icons.timer_outlined,
                title: 'Auto-lock',
                subtitle: settings.autoLockMinutes == 0
                    ? 'Never lock automatically. Not recommended.'
                    : 'Lock after ${settings.autoLockMinutes} minute${settings.autoLockMinutes == 1 ? '' : 's'} without use.',
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: settings.autoLockMinutes,
                    isDense: true,
                    borderRadius: BorderRadius.circular(12),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 min')),
                      DropdownMenuItem(value: 5, child: Text('5 min')),
                      DropdownMenuItem(value: 15, child: Text('15 min')),
                      DropdownMenuItem(value: 30, child: Text('30 min')),
                      DropdownMenuItem(value: 60, child: Text('1 hour')),
                      DropdownMenuItem(value: 0, child: Text('Never')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setAutoLockMinutes(value);
                    },
                  ),
                ),
              ),
              Divider(height: 1, color: palette.line),
              _Row(
                icon: Icons.fingerprint_rounded,
                title: 'Biometric unlock',
                subtitle: session.biometricAvailable
                    ? 'Use Face ID, Touch ID or your device fingerprint.'
                    : 'Not available on this device.',
                trailing: Switch(
                  value: settings.biometricUnlock && session.biometricAvailable,
                  onChanged: session.biometricAvailable
                      ? (value) => ref
                          .read(settingsControllerProvider.notifier)
                          .setBiometricUnlock(value)
                      : null,
                ),
              ),
              Divider(height: 1, color: palette.line),
              _Row(
                icon: Icons.password_rounded,
                title: 'Master password',
                subtitle:
                    'Changes the key to your vault. There is no recovery if you forget it.',
                onTap: () => _changePassword(context, ref),
                trailing:
                    Icon(Icons.chevron_right_rounded, color: palette.muted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _PermissionsSection(),
          _Section(
            title: 'Data & sync',
            children: [
              _Row(
                icon: Icons.sync_rounded,
                title: 'Sync',
                subtitle: _syncLabel(sync),
                trailing: TextButton(
                  onPressed: sync.syncing
                      ? null
                      : () async {
                          await ref.read(dataActionsProvider).syncNow();
                          if (!context.mounted) return;
                          final latest =
                              ref.read(syncStatusProvider).value.error;
                          showMessage(
                            context,
                            latest ?? 'Everything is up to date.',
                            error: latest != null,
                          );
                        },
                  child: Text(sync.syncing ? 'Syncing…' : 'Sync now'),
                ),
              ),
              Divider(height: 1, color: palette.line),
              _Row(
                icon: Icons.cloud_off_outlined,
                title: 'Local-first',
                subtitle:
                    'Changes are saved here first. Sync only carries ciphertext.',
                trailing: StatusPill(
                  label: sync.connected ? 'Connected' : 'Local',
                  tone: sync.connected ? PillTone.teal : PillTone.neutral,
                ),
              ),
              Divider(height: 1, color: palette.line),
              _Row(
                icon: Icons.delete_outline_rounded,
                title: 'Delete account',
                subtitle:
                    'Erase the encrypted vault on the server and everything on this device.',
                danger: true,
                onTap: () => _deleteAccount(context, ref),
                trailing:
                    Icon(Icons.chevron_right_rounded, color: palette.danger),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'About',
            children: [
              const _Row(
                icon: Icons.shield_outlined,
                title: 'Encryption',
                subtitle: 'AES-256-GCM · PBKDF2-HMAC-SHA256 · 210,000 rounds',
              ),
              Divider(height: 1, color: palette.line),
              const _VersionRow(),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.tealSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.visibility_off_outlined,
                    size: 20, color: palette.teal),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aethel keeps the ciphertext. You keep the key. Titles, passwords and notes are encrypted on this device before they reach the server.',
                    style: textTheme.bodySmall?.copyWith(
                      color: palette.ink,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _syncLabel(SyncStatus sync) {
    if (sync.syncing) return 'Sending and receiving changes…';
    if (sync.error != null) return sync.error!;
    if (sync.lastSync != null) {
      return 'Last synced ${DateFormat('d MMM, HH:mm').format(sync.lastSync!)}';
    }
    return 'Waiting for the first sync.';
  }

  String _premiumLabel(PremiumState premium) {
    if (premium.isPremium) {
      final expiresAt = premium.expiresAt;
      return expiresAt == null
          ? 'Active on this account.'
          : 'Active · renews ${DateFormat('d MMM yyyy').format(expiresAt)}';
    }
    if (premium.pendingOrderId != null) {
      return 'Waiting for payment confirmation.';
    }
    return 'Free plan · 15 entries, 5 bills, 1 schedule';
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Sign out?',
      message:
          'The local copy of your vault will be wiped from this device. Your encrypted data stays on the server and can be opened again with your master password.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(sessionControllerProvider.notifier).logout();
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final changed = await showAethelSheet<bool>(
      context: context,
      builder: (_) => _ChangePasswordSheet(ref: ref),
    );
    if (changed == true && context.mounted) {
      showMessage(context, 'Master password changed.');
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final deleted = await showAethelSheet<bool>(
      context: context,
      builder: (_) => _DeleteAccountSheet(ref: ref),
    );
    if (deleted == true && context.mounted) {
      showMessage(context, 'Your account and vault were deleted.');
    }
  }
}

/// The permissions this device actually has something to say about.
/// Renders nothing on platforms where neither feature needs permission.
class _PermissionsSection extends StatefulWidget {
  const _PermissionsSection();

  @override
  State<_PermissionsSection> createState() => _PermissionsSectionState();
}

class _PermissionsSectionState extends State<_PermissionsSection>
    with WidgetsBindingObserver {
  List<PermissionEntry> _entries = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from a system settings screen — read whatever they changed.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final entries = await PermissionCatalog.load();
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _act(PermissionEntry entry) async {
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
    if (_entries.isEmpty) return const SizedBox.shrink();
    final palette = context.aethel;
    return Column(
      children: [
        _Section(
          title: 'Permissions',
          children: [
            for (var index = 0; index < _entries.length; index++) ...[
              if (index > 0) Divider(height: 1, color: palette.line),
              _PermissionRow(
                  entry: _entries[index], onAct: () => _act(_entries[index])),
            ],
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.entry, required this.onAct});

  final PermissionEntry entry;
  final VoidCallback onAct;

  @override
  Widget build(BuildContext context) {
    final Widget trailing = switch (entry.stage) {
      PermissionStage.granted => const StatusPill(
          label: 'Granted',
          tone: PillTone.teal,
          icon: Icons.check_rounded,
        ),
      PermissionStage.notNeeded => const StatusPill(label: 'Not needed'),
      PermissionStage.blocked => TextButton(
          onPressed: onAct,
          child: const Text('Settings'),
        ),
      _ => TextButton(
          onPressed: onAct,
          child: const Text('Allow'),
        ),
    };
    return _Row(
      icon: entry.key == 'reminders'
          ? Icons.notifications_none_rounded
          : Icons.apps_outlined,
      title: entry.title,
      subtitle: entry.detail,
      trailing: trailing,
      onTap: entry.needsAction ? onAct : null,
    );
  }
}

/// Installed version, and the hand-rolled path to a newer one.
class _VersionRow extends ConsumerStatefulWidget {
  const _VersionRow();

  @override
  ConsumerState<_VersionRow> createState() => _VersionRowState();
}

class _VersionRowState extends ConsumerState<_VersionRow> {
  String _version = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then(
      (info) {
        if (mounted) setState(() => _version = info.version);
      },
      onError: (_) {
        if (mounted) setState(() => _version = 'unknown');
      },
    );
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() => _busy = true);
    final dialogContext = context;
    await promptUpdateIfAvailable(dialogContext, ref, force: true);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return _Row(
      icon: Icons.info_outline_rounded,
      title: 'Version',
      subtitle: _version.isEmpty ? 'Aethel' : 'Aethel $_version',
      trailing: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: _check,
              child: const Text('Check for updates'),
            ),
      onTap: _busy ? null : _check,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    return PaperCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: palette.muted,
                    letterSpacing: 0.9,
                  ),
            ),
          ),
          Divider(height: 1, color: palette.line),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        children: [
          Icon(icon, size: 19, color: danger ? palette.danger : palette.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    color: danger ? palette.danger : palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({required this.ref});

  final WidgetRef ref;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final controller = widget.ref.read(sessionControllerProvider.notifier);
    final ok = await controller.changeMasterPassword(
      currentPassword: _current.text,
      newPassword: _new.text,
    );
    if (!mounted) return;
    if (ok) {
      controller.clearError();
      Navigator.of(context).pop(true);
      return;
    }
    final message = widget.ref.read(sessionControllerProvider).error ??
        'The master password could not be changed.';
    controller.clearError();
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          title: 'Change master password',
          subtitle:
              'Your vault is re-keyed on this device. The server only receives a new verifier.',
          trailing: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
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
                  const FieldLabel('Current master password'),
                  _SecretField(
                    controller: _current,
                    hint: 'The one that opens the vault now',
                    validator: (value) => (value ?? '').isEmpty
                        ? 'Enter your current master password.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('New master password'),
                  _SecretField(
                    controller: _new,
                    hint: 'At least 20 characters',
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if ((value ?? '').length < 20) {
                        return 'Use at least 20 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  PasswordStrengthMeter(controller: _new),
                  const SizedBox(height: 16),
                  const FieldLabel('Repeat the new password'),
                  _SecretField(
                    controller: _confirm,
                    hint: 'Type it again',
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    validator: (value) => value != _new.text
                        ? 'The two new passwords do not match.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'There is no recovery if you forget this password. Aethel never sees it.',
                    style: textTheme.bodySmall?.copyWith(
                      color: palette.muted,
                      height: 1.5,
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
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change password'),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet({required this.ref});

  final WidgetRef ref;

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _password = TextEditingController();
  bool _understood = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your master password to confirm.');
      return;
    }
    if (!_understood) {
      setState(() => _error = 'Confirm that you understand this is permanent.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final controller = widget.ref.read(sessionControllerProvider.notifier);
    final ok = await controller.deleteAccount(
      masterPassword: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      controller.clearError();
      Navigator.of(context).pop(true);
      return;
    }
    final message = widget.ref.read(sessionControllerProvider).error ??
        'The account could not be deleted.';
    controller.clearError();
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          title: 'Delete account',
          subtitle:
              'This removes the encrypted vault from the server and this device.',
          trailing: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
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
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.dangerSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 20, color: palette.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Every password, card and note will be permanently lost. There is no backup and no recovery.',
                          style: textTheme.bodySmall?.copyWith(
                            color: palette.ink,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const FieldLabel('Master password'),
                _SecretField(
                  controller: _password,
                  hint: 'Confirm with your master password',
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _delete(),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: _understood,
                  onChanged: (value) =>
                      setState(() => _understood = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'I understand this cannot be undone.',
                    style: textTheme.bodySmall?.copyWith(color: palette.ink),
                  ),
                ),
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
              style: FilledButton.styleFrom(backgroundColor: palette.danger),
              onPressed: _busy ? null : _delete,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Delete everything'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SecretField extends StatefulWidget {
  const _SecretField({
    required this.controller,
    this.hint,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        hintText: widget.hint,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 19,
          ),
          tooltip: _obscure ? 'Show password' : 'Hide password',
        ),
      ),
    );
  }
}
