import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';
import '../../../widgets/page.dart';
import '../../../widgets/paper.dart';
import '../../../widgets/vault_visuals.dart';
import 'vault_detail_screen.dart';
import 'vault_editor.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _searchController = TextEditingController();
  VaultType? _type;
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _filtering =>
      _type != null ||
      _favoritesOnly ||
      _searchController.text.trim().isNotEmpty;

  void _clearFilters() {
    setState(() {
      _type = null;
      _favoritesOnly = false;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final items = ref.watch(vaultItemsProvider);
    final query = _searchController.text.trim().toLowerCase();
    final filtered = items.where((item) {
      if (_favoritesOnly && !item.favorite) return false;
      if (_type != null && item.type != _type) return false;
      if (query.isNotEmpty && !item.searchText.contains(query)) return false;
      return true;
    }).toList();

    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'The vault',
            subtitle:
                'Passwords, cards and private notes. Sealed before they leave this device.',
            action: FilledButton.icon(
              onPressed: () => showVaultEditor(context, ref),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('New entry'),
            ),
          ),
          const SizedBox(height: 26),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search titles, usernames, notes…',
              prefixIcon: const Icon(Icons.search_rounded, size: 21),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded, size: 19),
                      tooltip: 'Clear search',
                    ),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _type == null && !_favoritesOnly,
                  onTap: () => setState(() {
                    _type = null;
                    _favoritesOnly = false;
                  }),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Favourites',
                  icon: Icons.star_rounded,
                  selected: _favoritesOnly,
                  onTap: () => setState(() => _favoritesOnly = !_favoritesOnly),
                ),
                for (final type in VaultType.values) ...[
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: type.label,
                    icon: vaultIcon(type),
                    selected: _type == type,
                    onTap: () => setState(
                      () => _type = _type == type ? null : type,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                items.isEmpty
                    ? 'No entries'
                    : '${filtered.length} of ${items.length} ${items.length == 1 ? 'entry' : 'entries'}',
                style: textTheme.bodySmall?.copyWith(color: palette.muted),
              ),
              const Spacer(),
              if (_filtering)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear filters'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            PaperCard(
              padding: EdgeInsets.zero,
              child: EmptyState(
                icon: items.isEmpty
                    ? Icons.lock_outline_rounded
                    : Icons.search_off_rounded,
                title: items.isEmpty
                    ? 'Your strongbox is empty.'
                    : 'Nothing matches that search.',
                body: items.isEmpty
                    ? 'Start with a login, a card, or a note you want kept private.'
                    : 'Try a different word, or clear the filters to see everything.',
                action: items.isEmpty
                    ? FilledButton.icon(
                        onPressed: () => showVaultEditor(context, ref),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add your first entry'),
                      )
                    : TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear filters'),
                      ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 960
                    ? 3
                    : constraints.maxWidth >= 620
                        ? 2
                        : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in filtered)
                      SizedBox(
                        width: width,
                        child: _VaultTile(item: item),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _VaultTile extends StatelessWidget {
  const _VaultTile({required this.item});

  final VaultItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${item.title}, ${item.type.label}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showVaultDetail(context, item),
          borderRadius: BorderRadius.circular(22),
          focusColor: palette.tealSoft,
          child: Ink(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: palette.line),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 148),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBadge(icon: vaultIcon(item.type), size: 36),
                        const Spacer(),
                        if (item.favorite)
                          Icon(Icons.star_rounded,
                              size: 17, color: palette.brass),
                        if (item.pending) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: palette.brass,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle.isEmpty
                          ? vaultTypeDescription(item.type)
                          : item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          item.type.label,
                          style: textTheme.labelSmall?.copyWith(
                            color: palette.teal,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: palette.muted,
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
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? palette.teal : palette.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? palette.teal : palette.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : palette.muted,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : palette.ink,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
