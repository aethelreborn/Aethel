import 'package:flutter/material.dart';
import 'package:aethel/core/constants/colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.transparent, elevation: 0),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _SettingTile(icon: Icons.notifications, title: 'Notifications', subtitle: 'Due-date & price-change alerts', isDark: isDark),
        _SettingTile(icon: Icons.lock_reset, title: 'Change Master Password', isDark: isDark),
        _SettingTile(icon: Icons.upload, title: 'Export Data', subtitle: 'Download encrypted backup', isDark: isDark),
        _SettingTile(icon: Icons.delete_forever, title: 'Delete Account', subtitle: 'Permanently remove all data', isDark: isDark, accent: AppColors.urgentLight),
      ]),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool isDark;
  final Color? accent;
  const _SettingTile({required this.icon, required this.title, this.subtitle = '', required this.isDark, this.accent});
  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? AppColors.bgSurfaceDark : AppColors.bgSurfaceLight, borderRadius: BorderRadius.circular(12)), child: Row(children: [
      Icon(icon, color: accent ?? AppColors.accentLight),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))])),
      Icon(Icons.chevron_right, color: Colors.grey.shade400),
    ]));
  }
}
