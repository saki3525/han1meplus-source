import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class LibraryTabEntry {
  const LibraryTabEntry({required this.key, required this.label});

  final String key;
  final String label;
}

class LibraryTabStrip extends StatelessWidget {
  const LibraryTabStrip({super.key, required this.controller, required this.tabs});

  final TabController controller;
  final List<LibraryTabEntry> tabs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelStyle = theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerHeight: 0,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 2),
        indicator: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(24)),
        indicatorAnimation: TabIndicatorAnimation.elastic,
        labelColor: colors.onPrimary,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: labelStyle?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: labelStyle,
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        tabs: [
          for (final tab in tabs)
            Tab(
              height: 48,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(tab.label, textAlign: TextAlign.center),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LibraryFilterBar extends StatelessWidget {
  const LibraryFilterBar({
    super.key,
    required this.controller,
    required this.tabs,
    required this.count,
    required this.searchExpanded,
    required this.onToggleSearch,
    this.onAddPlaylist,
  });

  final TabController controller;
  final List<LibraryTabEntry> tabs;
  final int Function(String key) count;
  final bool searchExpanded;
  final VoidCallback onToggleSearch;
  final VoidCallback? onAddPlaylist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final index = controller.index.clamp(0, tabs.length - 1);
        final showAddPlaylist = tabs[index].key == 'playlists' && onAddPlaylist != null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.libraryItemsCount(count(tabs[index].key)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              _AnimatedPlaylistAction(visible: showAddPlaylist, onPressed: onAddPlaylist),
              IconButton(
                tooltip: searchExpanded ? l10n.close : l10n.searchLibrary,
                isSelected: searchExpanded,
                selectedIcon: const Icon(Icons.search_off_rounded),
                icon: const Icon(Icons.search_rounded),
                onPressed: onToggleSearch,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedPlaylistAction extends StatelessWidget {
  const _AnimatedPlaylistAction({required this.visible, this.onPressed});

  final bool visible;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: visible ? 1 : 0),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Opacity(
              opacity: value,
              child: Transform.scale(scale: .6 + .4 * value, child: child),
            ),
          ),
        ),
        child: IgnorePointer(
          ignoring: !visible,
          child: IconButton(
            tooltip: AppLocalizations.of(context)!.newPlaylist,
            onPressed: onPressed,
            icon: const Icon(Icons.playlist_add_rounded),
          ),
        ),
      );
}

class LibrarySearchField extends StatelessWidget {
  const LibrarySearchField({super.key, required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SearchBar(
        controller: controller,
        autoFocus: true,
        elevation: const WidgetStatePropertyAll(0.0),
        backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surfaceContainerLow),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
        constraints: const BoxConstraints(minHeight: 48),
        leading: const Icon(Icons.search_rounded, size: 22),
        trailing: [
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: l10n.clearSearch,
              onPressed: () {
                controller.clear();
                onChanged('');
              },
              icon: const Icon(Icons.close_rounded),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
