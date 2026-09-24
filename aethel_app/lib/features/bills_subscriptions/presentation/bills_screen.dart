import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aethel/core/constants/colors.dart';
import 'package:aethel/domain/models/models.dart';
import 'package:aethel/features/dashboard/providers/timeline_provider.dart';
import 'package:aethel/features/bills_subscriptions/presentation/bill_edit_screen.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});
  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  Future<void> _refresh() async {
    await ref.read(billingProvider.notifier).fetch();
  }

  Future<void> _addBill() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const BillEditScreen()),
    );
    if (result == true && mounted) await _refresh();
  }

  String _filterTab(String filter) {
    switch (_tabCtrl.index) {
      case 1: return 'upcoming';
      case 2: return 'paid';
      default: return 'all';
    }
  }

  List<BillingEntry> _filterBills(List<BillingEntry> bills, String filter) {
    switch (filter) {
      case 'upcoming':
        return bills.where((b) => b.urgency == UrgencyLevel.upcoming || b.urgency == UrgencyLevel.urgent).toList();
      case 'paid':
        return bills.where((b) => !b.isActive).toList();
      default:
        return bills;
    }
  }

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final billingAsync = ref.watch(billingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills & Subscriptions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(controller: _tabCtrl, tabs: const [Tab(text: 'All'), Tab(text: 'Upcoming'), Tab(text: 'Paid')]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: billingAsync.when(
        data: (bills) {
          final filtered = _filterBills(bills, _filterTab(''));
          if (filtered.isEmpty && _tabCtrl.index == 0) {
            return const Center(child: Text('No bills yet. Add your first one!', style: TextStyle(color: Colors.grey)));
          }
          if (filtered.isEmpty) {
            return const Center(child: Text('None in this category.', style: TextStyle(color: Colors.grey)));
          }
          return TabBarView(
            controller: _tabCtrl,
            children: [
              _BillList(bills: bills, isDark: isDark, onRefresh: _refresh),
              _BillList(bills: _filterBills(bills, 'upcoming'), isDark: isDark, onRefresh: _refresh),
              _BillList(bills: _filterBills(bills, 'paid'), isDark: isDark, onRefresh: _refresh),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text('Failed to load bills', style: TextStyle(color: Colors.grey.shade500))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBill,
        label: const Text('Add Bill'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _BillList extends StatelessWidget {
  final List<BillingEntry> bills;
  final bool isDark;
  final VoidCallback onRefresh;

  const _BillList({required this.bills, required this.isDark, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) return const Center(child: Text('No bills here yet.', style: TextStyle(color: Colors.grey)));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bills.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _BillTile(item: bills[i], isDark: isDark),
    );
  }
}

class _BillTile extends StatelessWidget {
  final BillingEntry item;
  final bool isDark;

  const _BillTile({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isRef = ref.watch(billingProvider.notifier);
    final color = _colorFor(item.urgency, isDark);
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(color: AppColors.urgent(context), alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white)),
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Bill'),
            content: Text('Delete "${item.title}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (direction) async {
        await ref.read(billingProvider.notifier).delete(item.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: isDark ? AppColors.bgSurfaceDark : AppColors.bgSurfaceLight, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.15), child: Icon(Icons.receipt, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(item.nextDueDate != null ? '${_fmtDate(item.nextDueDate!)}' : 'No due date', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('\$${item.amountDue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (!item.isActive)
              Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text('PAID', style: TextStyle(fontSize: 10, color: color))),
            if (item.isActive)
              ElevatedButton(
                onPressed: () async {
                  await ref.read(billingProvider.notifier).markPaid(item.id);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.resolved(context), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                child: const Text('Paid', style: TextStyle(fontSize: 10)),
              ),
          ]),
        ]),
      ),
    );
  }

  Color _colorFor(UrgencyLevel urgency, bool isDark) {
    switch (urgency) {
      case UrgencyLevel.urgent: return AppColors.urgentLight;
      case UrgencyLevel.upcoming: return AppColors.upcomingLight;
      case UrgencyLevel.scheduled: return AppColors.informationalLight;
      case UrgencyLevel.resolved: return AppColors.resolvedLight;
    }
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now).inDays;
    if (diff < 0) return '${-diff}d overdue';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '${dt.month}/${dt.day}';
  }
}
