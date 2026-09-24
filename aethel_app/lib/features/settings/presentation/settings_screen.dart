import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aethel/core/constants/colors.dart';
import 'package:aethel/core/crypto/secure_key_store.dart';
import 'package:aethel/core/network/api_client.dart';
import 'package:aethel/features/auth/providers/auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _storageProvider = Provider((ref) => const FlutterSecureStorage());

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.transparent, elevation: 0),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _SettingTile(
          icon: Icons.notifications,
          title: 'Notifications',
          subtitle: 'Due-date & price-change alerts',
          isDark: isDark,
          onTap: () async {
            final storage = ref.read(_storageProvider);
            final enabled = (await storage.read(key: 'notifications_enabled')) != 'false';
            await storage.write(key: 'notifications_enabled', value: enabled ? 'false' : 'true');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(enabled ? 'Notifications disabled' : 'Notifications enabled')),
              );
            }
          },
        ),
        _SettingTile(
          icon: Icons.lock_reset,
          title: 'Change Master Password',
          isDark: isDark,
          onTap: () async {
            final oldPwCtrl = TextEditingController();
            final newPwCtrl = TextEditingController();
            final confirmPwCtrl = TextEditingController();
            final formKey = GlobalKey<FormState>();
            bool obscureNew = true, obscureConfirm = true;
            String? error;

            final result = await showDialog<bool>(
              context: context,
              builder: (ctx) => StatefulBuilder(
                builder: (ctx, setDialogState) => AlertDialog(
                  title: const Text('Change Master Password'),
                  content: Form(
                    key: formKey,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextFormField(
                        controller: oldPwCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Current Password'),
                        validator: (v) => (v?.length ?? 0) < 1 ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newPwCtrl,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (v) => (v?.length ?? 0) < 8 ? 'Min 8 characters' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPwCtrl,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                        validator: (v) => v != newPwCtrl.text ? 'Passwords do not match' : null,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ],
                    ]),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => error = null);
                        try {
                          await SecureKeyStore(storage: const FlutterSecureStorage()).storeDerivedKey(newPwCtrl.text);
                          if (mounted) Navigator.of(context).pop(true);
                        } catch (e) {
                          setDialogState(() => error = e.toString());
                        }
                      },
                      child: const Text('Update'),
                    ),
                  ],
                ),
              ),
            );

            if (result == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Master password updated')),
              );
            }

            oldPwCtrl.dispose();
            newPwCtrl.dispose();
            confirmPwCtrl.dispose();
          },
        ),
        _SettingTile(
          icon: Icons.upload,
          title: 'Export Data',
          subtitle: 'Download encrypted backup',
          isDark: isDark,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon')),
            );
          },
        ),
        _SettingTile(
          icon: Icons.delete_forever,
          title: 'Delete Account',
          subtitle: 'Permanently remove all data',
          isDark: isDark,
          accent: AppColors.urgentLight,
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Account'),
                content: const Text('This will permanently delete your account and all associated data. This action cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.urgentLight),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !mounted) return;

            try {
              await ApiClient.dio.delete('/auth/account');
            } catch (_) {}

            await ref.read(authStateProvider.notifier).logout();
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
        ),
        _SettingTile(
          icon: Icons.logout,
          title: 'Logout',
          isDark: isDark,
          onTap: () async {
            await ref.read(authStateProvider.notifier).logout();
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
        ),
      ]),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool isDark;
  final Color? accent;
  final VoidCallback onTap;
  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle = '',
    required this.isDark,
    this.accent,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgSurfaceDark : AppColors.bgSurfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, color: accent ?? AppColors.accentLight),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ])),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}
