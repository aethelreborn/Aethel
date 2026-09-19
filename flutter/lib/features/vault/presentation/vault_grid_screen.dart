import 'package:flutter/material.dart';
import 'package:aethel/core/constants/colors.dart';

class VaultGridScreen extends StatefulWidget {
  const VaultGridScreen({super.key});
  @override
  State<VaultGridScreen> createState() => _VaultGridScreenState();
}

class _VaultGridScreenState extends State<VaultGridScreen> {
  String _filter = 'All';
  final _filters = ['All', 'Passwords', 'Cards', 'Notes'];
  final _items = List.generate(6, (i) => _VaultItem(title: 'Item $i', type: i % 3 == 0 ? 'password' : i % 3 == 1 ? 'card' : 'note'));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filter == 'All' ? _items : _items.where((it) => it.type == _filter.toLowerCase()).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Vault'), backgroundColor: Colors.transparent, elevation: 0),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 8, children: _filters.map((f) => ChoiceChip(label: Text(f), selected: _filter == f, onSelected: (_) => setState(() => _filter = f))).toList())),
        Expanded(child: GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1), itemCount: filtered.length, itemBuilder: (_, i) => _VaultCard(item: filtered[i], isDark: isDark))),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () {}, label: const Text('Add'), icon: const Icon(Icons.add)),
    );
  }
}

class _VaultItem {
  final String title;
  final String type;
  _VaultItem({required this.title, required this.type});
}

class _VaultCard extends StatelessWidget {
  final _VaultItem item;
  final bool isDark;
  const _VaultCard({required this.item, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final color = item.type == 'password' ? AppColors.accentLight : item.type == 'card' ? AppColors.upcomingLight : AppColors.informationalLight;
    return Card(child: InkWell(onTap: () {}, child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(item.type == 'password' ? Icons.lock_outline : item.type == 'card' ? Icons.credit_card : Icons.note, size: 32, color: color),
      const SizedBox(height: 12),
      Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      Text(item.type.toUpperCase(), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ]))),);
  }
}
