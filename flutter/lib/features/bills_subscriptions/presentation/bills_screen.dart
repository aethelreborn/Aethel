import 'package:flutter/material.dart';
import 'package:aethel/core/constants/colors.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});
  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _bills = List.generate(5, (i) => _BillItem(title: 'Bill $i', amount: 50.0 + i * 10, dueDate: '2026-09-${15 + i}', status: i == 0 ? 'overdue' : i < 3 ? 'upcoming' : 'paid'));

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills & Subscriptions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(controller: _tabCtrl, tabs: const [Tab(text: 'All'), Tab(text: 'Upcoming'), Tab(text: 'Paid')]),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _BillList(bills: _bills, isDark: isDark),
          _BillList(bills: _bills.where((b) => b.status == 'upcoming').toList(), isDark: isDark),
          _BillList(bills: _bills.where((b) => b.status == 'paid').toList(), isDark: isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () {}, label: const Text('Add Bill'), icon: const Icon(Icons.add)),
    );
  }
}

class _BillItem {
  final String title;
  final double amount;
  final String dueDate;
  final String status;
  _BillItem({required this.title, required this.amount, required this.dueDate, required this.status});
}

class _BillList extends StatelessWidget {
  final List<_BillItem> bills;
  final bool isDark;
  const _BillList({required this.bills, required this.isDark});
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
  final _BillItem item;
  final bool isDark;
  const _BillTile({required this.item, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final color = item.status == 'overdue' ? AppColors.urgentLight : item.status == 'upcoming' ? AppColors.upcomingLight : AppColors.resolvedLight;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? AppColors.bgSurfaceDark : AppColors.bgSurfaceLight, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.15), child: Icon(Icons.receipt, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(item.dueDate, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('\$${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(item.status.toUpperCase(), style: TextStyle(fontSize: 10, color: color)),
          ),
        ]),
      ]),
    );
  }
}
