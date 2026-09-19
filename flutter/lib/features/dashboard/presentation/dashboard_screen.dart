import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aethel/core/constants/colors.dart';
import 'package:aethel/domain/models/models.dart';
import 'package:aethel/features/dashboard/providers/timeline_provider.dart';
import 'package:aethel/features/vault/presentation/vault_grid_screen.dart';
import 'package:aethel/features/bills_subscriptions/presentation/bills_screen.dart';
import 'package:aethel/features/focus_blocker/presentation/focus_panel_screen.dart';
import 'package:aethel/features/settings/presentation/settings_screen.dart';

final currentPageProvider = StateProvider<int>((ref) => 0);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;
  static const _pages = [
    DashboardHomeTab(),
    VaultGridScreen(),
    BillsScreen(),
    FocusPanelScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.bgSurfaceDark
            : AppColors.bgSurfaceLight,
        indicatorColor: AppColors.accentLight.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.lock_outline), selectedIcon: Icon(Icons.lock), label: 'Vault'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Bills'),
          NavigationDestination(icon: Icon(Icons.do_not_disturb_on_outlined), selectedIcon: Icon(Icons.do_not_disturb_on), label: 'Focus'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ── Home Tab ─────────────────────────────────────────────────────────────────

class DashboardHomeTab extends ConsumerWidget {
  const DashboardHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vaultAsync = ref.watch(vaultProvider);
    final billingAsync = ref.watch(billingProvider);

    // Compute metrics from live data
    int activeSubs = 0;
    int weeklyDue = 0;
    final now = DateTime.now();

    billingAsync.whenData((items) {
      for (final b in items) {
        if (b.isActive) activeSubs++;
        final daysUntil = b.nextDueDate?.difference(now).inDays ?? 999;
        if (daysUntil >= 0 && daysUntil <= 7) weeklyDue++;
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgPrimaryDark : AppColors.bgPrimaryLight,
      appBar: AppBar(
        title: const Text('Aethel'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(vaultProvider.notifier).fetch();
          await ref.read(billingProvider.notifier).fetch();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Greeting
            Text(
              _greeting(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 20),

            // Metric chips
            Row(
              children: [
                Expanded(
                  child: _MetricChip(
                    icon: Icons.subscriptions,
                    label: 'Active Subs',
                    value: '$activeSubs',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricChip(
                    icon: Icons.calendar_today,
                    label: 'Weekly Due',
                    value: '$weeklyDue',
                    isDark: isDark,
                    accent: weeklyDue > 0 ? AppColors.upcomingLight : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Timeline header
            Row(
              children: [
                Text('Timeline', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(onPressed: () {}, child: const Text('View all', style: TextStyle(fontSize: 13))),
              ],
            ),
            const SizedBox(height: 12),

            // Timeline events
            vaultAsync.when(
              data: (vaultItems) {
                final billingItems = billingAsync.value ?? [];
                final events = <TimelineEvent>[];

                for (final v in vaultItems) {
                  events.add(TimelineEvent(
                    id: v.id,
                    title: 'Vault entry ${v.type.name}',
                    subtitle: v.title,
                    urgency: UrgencyLevel.scheduled,
                    timestamp: v.updatedAt,
                    module: 'vault',
                  ));
                }
                for (final b in billingItems) {
                  if (b.nextDueDate != null) {
                    events.add(TimelineEvent(
                      id: b.id,
                      title: b.title,
                      subtitle: '\$${b.amountDue.toStringAsFixed(2)} — ${_fmtDate(b.nextDueDate!)}',
                      urgency: b.urgency,
                      timestamp: b.nextDueDate!,
                      module: 'billing',
                    ));
                  }
                }

                events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                final limited = events.take(10).toList();

                if (limited.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(
                        children: [
                          Icon(Icons.timeline, size: 48, color: (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight).withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text('Nothing here yet — add your first item!',
                              style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: limited.map((e) => _TimelineTile(event: e, isDark: isDark)).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(child: Text('Failed to load', style: TextStyle(color: Colors.grey.shade500))),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now).inDays;
    if (diff < 0) return '${-diff}d overdue';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '${dt.day}/${dt.month}';
  }
}

// ── Metric Chip ────────────────────────────────────────────────────────────────

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool isDark;
  final Color? accent;
  const _MetricChip({required this.icon, required this.label, required this.value, required this.isDark, this.accent});

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppColors.accentLight;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgSurfaceDark : AppColors.bgSurfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, color: c, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ])),
      ]),
    );
  }
}

// ── Timeline Tile ──────────────────────────────────────────────────────────────

class _TimelineTile extends StatelessWidget {
  final TimelineEvent event;
  final bool isDark;
  const _TimelineTile({required this.event, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(event.urgency);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgSurfaceDark : AppColors.bgSurfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(children: [
        Icon(_iconFor(event.module), size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(event.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ])),
        Text(_timeAgo(event.timestamp), style: TextStyle(fontSize: 11, color: color)),
      ]),
    );
  }

  Color _colorFor(UrgencyLevel u) {
    switch (u) {
      case UrgencyLevel.urgent: return AppColors.urgentLight;
      case UrgencyLevel.upcoming: return AppColors.upcomingLight;
      case UrgencyLevel.scheduled: return AppColors.informationalLight;
      case UrgencyLevel.resolved: return AppColors.resolvedLight;
    }
  }

  IconData _iconFor(String module) {
    switch (module) {
      case 'vault': return Icons.lock_outline;
      case 'billing': return Icons.receipt_long;
      case 'schedule': return Icons.schedule;
      default: return Icons.circle;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
