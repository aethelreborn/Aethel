import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/network/sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/brand.dart';
import '../../bills/presentation/bills_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../focus/presentation/focus_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../vault/presentation/vault_screen.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _destinations = <_Destination>[
    _Destination('Home', Icons.home_outlined, Icons.home_rounded),
    _Destination('Vault', Icons.lock_outline_rounded, Icons.lock_rounded),
    _Destination(
        'Bills', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    _Destination(
        'Focus', Icons.hourglass_empty_rounded, Icons.hourglass_bottom_rounded),
    _Destination('Settings', Icons.tune_rounded, Icons.tune_rounded),
  ];

  static const _screens = <Widget>[
    DashboardScreen(),
    VaultScreen(),
    BillsScreen(),
    FocusScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellIndexProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final body = IndexedStack(index: index, children: _screens);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _SideRail(index: index),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) =>
            ref.read(shellIndexProvider.notifier).state = value,
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _SideRail extends ConsumerWidget {
  const _SideRail({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.aethel;
    final session = ref.watch(sessionControllerProvider);
    final sync = ref.watch(syncStatusProvider).value;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final name = session.profile?.name.trim() ?? '';
    final firstName = name.isEmpty ? '' : name.split(' ').first;

    return Container(
      width: 242,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(right: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: BrandLockup(),
              ),
              const SizedBox(height: 38),
              for (var itemIndex = 0;
                  itemIndex < AppShell._destinations.length;
                  itemIndex++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _RailItem(
                    destination: AppShell._destinations[itemIndex],
                    selected: index == itemIndex,
                    reduceMotion: reduceMotion,
                    onTap: () =>
                        ref.read(shellIndexProvider.notifier).state = itemIndex,
                  ),
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (firstName.isNotEmpty) ...[
                      Text(
                        firstName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.profile?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: palette.muted),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _SyncLine(status: sync),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(sessionControllerProvider.notifier).lock(),
                        icon: const Icon(Icons.lock_outline_rounded, size: 18),
                        label: const Text('Lock now'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Sealed on this device.\nSynced as ciphertext.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: palette.muted, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.reduceMotion,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          focusColor: palette.tealSoft,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? palette.tealSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: selected ? palette.teal : palette.muted,
                ),
                const SizedBox(width: 12),
                Text(
                  destination.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: selected ? palette.teal : palette.ink,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncLine extends StatelessWidget {
  const _SyncLine({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final (color, label) = status.syncing
        ? (palette.brass, 'Syncing changes')
        : status.error != null
            ? (palette.brass, 'Local only')
            : (palette.success, 'Synced');
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}
