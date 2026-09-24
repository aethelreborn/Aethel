import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aethel/core/constants/colors.dart';
import 'package:aethel/domain/models/models.dart';
import 'package:aethel/features/dashboard/providers/timeline_provider.dart';
import 'package:aethel/features/vault/presentation/vault_detail_screen.dart';
import 'package:aethel/features/vault/presentation/vault_edit_screen.dart';

class VaultGridScreen extends ConsumerStatefulWidget {
  const VaultGridScreen({super.key});
  @override
  ConsumerState<VaultGridScreen> createState() => _VaultGridScreenState();
}

class _VaultGridScreenState extends ConsumerState<VaultGridScreen> {
  String _filter = 'All';
  final _filters = ['All', 'Passwords', 'Cards', 'Notes'];

  Future<void> _refresh() async {
    await ref.read(vaultProvider.notifier).fetch();
  }

  Future<void> _addEntry() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VaultEditScreen()),
    );
    if (result == true && mounted) await _refresh();
  }

  void _navigateToDetail(VaultEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VaultDetailScreen(entry: entry)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vaultAsync = ref.watch(vaultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            children: _filters.map((f) => ChoiceChip(
              label: Text(f),
              selected: _filter == f,
              onSelected: (_) => setState(() => _filter = f),
            )).toList(),
          ),
        ),
        Expanded(
          child: vaultAsync.when(
            data: (entries) {
              final filtered = _filter == 'All'
                  ? entries
                  : entries.where((e) {
                      final type = e.type.name.toLowerCase();
                      return type == _filter.toLowerCase();
                    }).toList();
              if (filtered.isEmpty) {
                return const Center(child: Text('No vault entries yet.', style: TextStyle(color: Colors.grey)));
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _VaultCard(
                  entry: filtered[i], isDark: isDark,
                  onTap: () => _navigateToDetail(filtered[i]),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(child: Text('Failed to load vault', style: TextStyle(color: Colors.grey.shade500))),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        label: const Text('Add'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _VaultCard extends StatelessWidget {
  final VaultEntry entry;
  final bool isDark;
  final VoidCallback onTap;

  const _VaultCard({required this.entry, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(entry.type, isDark);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_iconFor(entry.type), size: 32, color: color),
              const SizedBox(height: 12),
              Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(entry.type.name.toUpperCase(), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorFor(VaultItemType type, bool isDark) {
    switch (type) {
      case VaultItemType.password: return isDark ? AppColors.accentDark : AppColors.accentLight;
      case VaultItemType.card: return isDark ? AppColors.upcomingDark : AppColors.upcomingLight;
      case VaultItemType.note:
      case VaultItemType.secureNote: return isDark ? AppColors.informationalDark : AppColors.informationalLight;
      case VaultItemType.identity: return isDark ? AppColors.resolvedDark : AppColors.resolvedLight;
    }
  }

  IconData _iconFor(VaultItemType type) {
    switch (type) {
      case VaultItemType.password: return Icons.lock_outline;
      case VaultItemType.card: return Icons.credit_card;
      case VaultItemType.note:
      case VaultItemType.secureNote: return Icons.note;
      case VaultItemType.identity: return Icons.person_outline;
    }
  }
}
