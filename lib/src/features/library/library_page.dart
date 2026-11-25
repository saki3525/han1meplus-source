import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';

import '../../core/app_shell.dart';
import '../../core/settings.dart';
import '../../data/han1me_repository.dart';
import '../../data/local/library_repository.dart';
import '../../domain/models/library.dart';
import '../../domain/models/search_query.dart';
import '../../domain/models/video.dart';
import '../account/account_controller.dart';
import '../settings/settings_controller.dart';
import '../shared/search_loading_gate.dart';
import '../shared/video_card.dart';
import 'history_page.dart';
import 'library_empty_state.dart';
import 'library_tabs.dart';
import 'playlists/local_playlist_page.dart';
import 'playlists/playlist_shared.dart';
import 'playlists/remote_playlist_page.dart';
import 'remote_library_controller.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key, this.initialTab = 'watch-later'});

  final String initialTab;

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  String? _artistId;
  final _searchController = TextEditingController();
  var _searchExpanded = false;
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchExpanded = !_searchExpanded;
      if (!_searchExpanded) {
        _query = '';
        _searchController.clear();
      }
    });
  }

  void _onQueryChanged(String value) => setState(() => _query = value);

  @override
  Widget build(BuildContext context) {
    if (widget.initialTab == 'history') return const HistoryPage();
    final orderKey = ref.watch(settingsProvider.select((value) => (value.valueOrNull?.resolvedLibraryTabOrder ?? defaultLibraryTabKeys).join('|')));
    final order = orderKey.split('|');
    final initialTab = _normaliseLibraryTabKey(order, widget.initialTab);
    final initialIndex = _libraryTabIndex(order, initialTab);
    final drawerMode = ref.watch(settingsProvider.select((value) => value.valueOrNull?.useNavigationDrawer ?? false));
    final account = ref.watch(accountProvider).valueOrNull;
    final l10n = AppLocalizations.of(context)!;
    if (account?.id != null) {
      return _RemoteLibrary(
        order: order,
        initialIndex: initialIndex,
        initialTab: initialTab,
        drawerMode: drawerMode,
        query: _query,
        searchExpanded: _searchExpanded,
        searchController: _searchController,
        onToggleSearch: _toggleSearch,
        onQueryChanged: _onQueryChanged,
      );
    }
    final value = ref.watch(libraryProvider);
    if (drawerMode) {
      return Scaffold(
        appBar: AppBar(
          leading: Navigator.of(context).canPop() || permanentNavigationDrawer(context) ? null : IconButton(onPressed: openAppDrawer, icon: const Icon(Icons.menu)),
          title: Text(l10n.library),
        ),
        body: value.when(
          loading: () => const Center(child: M3EContainedLoadingIndicator()),
          error: (error, stackTrace) => Center(child: Text('$error')),
          data: (library) => Column(
            children: [
              _DrawerActionBar(
                count: _localCount(library, initialTab),
                searchExpanded: _searchExpanded,
                onToggleSearch: _toggleSearch,
                showPlaylistAction: initialTab == 'playlists',
                onAddPlaylist: () => _createLocalPlaylist(context, ref),
              ),
              _SearchFieldSlot(expanded: _searchExpanded, controller: _searchController, onChanged: _onQueryChanged),
              Expanded(
                child: SearchLoadingGate(
                  enabled: _searchExpanded,
                  loadingKey: _query.trim().isEmpty ? null : _query,
                  child: _tabContent(library, initialTab),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return DefaultTabController(
      length: order.length,
      initialIndex: initialIndex,
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          final tabs = _tabEntries(l10n, order);
          return Scaffold(
            appBar: AppBar(title: Text(l10n.library)),
            body: value.when(
              loading: () => const Center(child: M3EContainedLoadingIndicator()),
              error: (error, stackTrace) => Center(child: Text('$error')),
              data: (library) => Column(
                children: [
                  const SizedBox(height: 4),
                  LibraryTabStrip(controller: controller, tabs: tabs),
                  LibraryFilterBar(
                    controller: controller,
                    tabs: tabs,
                    count: (key) => _localCount(library, key),
                    searchExpanded: _searchExpanded,
                    onToggleSearch: _toggleSearch,
                    onAddPlaylist: () => _createLocalPlaylist(context, ref),
                  ),
                  _SearchFieldSlot(expanded: _searchExpanded, controller: _searchController, onChanged: _onQueryChanged),
                  Expanded(
                    child: SearchLoadingGate(
                      enabled: _searchExpanded,
                      loadingKey: _query.trim().isEmpty ? null : _query,
                      child: TabBarView(controller: controller, children: [for (final key in order) _tabContent(library, key)]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _localCount(LibraryState library, String key) => switch (key) {
        'watch-later' => _filterVideos(library.watchLater, _query).length,
        'favorites' => _filterVideos(library.favorites, _query).length,
        'playlists' => _filterPlaylists(library.playlists, _query).length,
        'subscriptions' => _uniqueVideos(_filterSubscriptionVideos(library.subscriptionVideos, _query)).length,
        _ => 0,
      };

  Widget _tabContent(LibraryState library, String key) {
    final l10n = AppLocalizations.of(context)!;
    return switch (key) {
      'watch-later' => _SelectableVideos(videos: _filterVideos(library.watchLater, _query), emptyMessage: l10n.noWatchLater, remover: (ref, ids) => ref.read(libraryProvider.notifier).removeWatchLater(ids)),
      'favorites' => _SelectableVideos(videos: _filterVideos(library.favorites, _query), emptyMessage: l10n.noFavoriteVideos, remover: (ref, ids) => ref.read(libraryProvider.notifier).removeFavorites(ids)),
      'playlists' => _LocalPlaylists(playlists: _filterPlaylists(library.playlists, _query)),
      'subscriptions' => _LocalSubscriptions(artists: _filterArtists(library.artists, _query), videos: _filterSubscriptionVideos(library.subscriptionVideos, _query), selectedArtist: _artistId, onSelected: (artist) => setState(() => _artistId = artist)),
      _ => _SelectableVideos(videos: _filterVideos(library.watchLater, _query), emptyMessage: l10n.noWatchLater, remover: (ref, ids) => ref.read(libraryProvider.notifier).removeWatchLater(ids)),
    };
  }

  Future<void> _createLocalPlaylist(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<PlaylistEditorResult>(context: context, builder: (_) => const PlaylistEditorDialog());
    if (result == null || result.title.isEmpty) return;
    await ref.read(libraryProvider.notifier).createPlaylist(result.title, description: result.description);
  }
}

class _SearchFieldSlot extends StatelessWidget {
  const _SearchFieldSlot({required this.expanded, required this.controller, required this.onChanged});

  final bool expanded;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        clipBehavior: Clip.hardEdge,
        child: expanded
            ? LibrarySearchField(controller: controller, onChanged: onChanged)
            : const SizedBox(width: double.infinity),
      );
}

class _RemoteLibrary extends ConsumerWidget {
  const _RemoteLibrary({
    required this.order,
    required this.initialIndex,
    required this.initialTab,
    required this.drawerMode,
    required this.query,
    required this.searchExpanded,
    required this.searchController,
    required this.onToggleSearch,
    required this.onQueryChanged,
  });

  final List<String> order;
  final int initialIndex;
  final String initialTab;
  final bool drawerMode;
  final String query;
  final bool searchExpanded;
  final TextEditingController searchController;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(accountProvider).valueOrNull;
    final token = account?.csrfToken;
    if (drawerMode) {
      return Scaffold(
        appBar: AppBar(leading: permanentNavigationDrawer(context) ? null : IconButton(onPressed: openAppDrawer, icon: const Icon(Icons.menu)), title: Text(l10n.library)),
        body: ref.watch(remoteLibraryProvider).when(
          loading: () => const Center(child: M3EContainedLoadingIndicator()),
          error: (error, stackTrace) => Center(child: FilledButton(onPressed: () => ref.invalidate(remoteLibraryProvider), child: Text(l10n.reload))),
          data: (library) => Column(
            children: [
              _DrawerActionBar(
                count: _remoteCount(library, initialTab),
                searchExpanded: searchExpanded,
                onToggleSearch: onToggleSearch,
                showPlaylistAction: initialTab == 'playlists',
                onAddPlaylist: (library.csrfToken ?? token) == null ? null : () => _createPlaylist(context, ref, (library.csrfToken ?? token)!),
              ),
              _SearchFieldSlot(expanded: searchExpanded, controller: searchController, onChanged: onQueryChanged),
              Expanded(
                child: SearchLoadingGate(
                  enabled: searchExpanded,
                  loadingKey: query.trim().isEmpty ? null : query,
                  child: _remoteTabContent(context, ref, library, initialTab, token),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return DefaultTabController(
      length: order.length,
      initialIndex: initialIndex,
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          final tabs = _tabEntries(l10n, order);
          return Scaffold(
            appBar: AppBar(title: Text(l10n.library)),
            body: ref.watch(remoteLibraryProvider).when(
              loading: () => const Center(child: M3EContainedLoadingIndicator()),
              error: (error, stackTrace) => Center(child: FilledButton(onPressed: () => ref.invalidate(remoteLibraryProvider), child: Text(l10n.reload))),
              data: (library) => Column(
                children: [
                  const SizedBox(height: 4),
                  LibraryTabStrip(controller: controller, tabs: tabs),
                  LibraryFilterBar(
                    controller: controller,
                    tabs: tabs,
                    count: (key) => _remoteCount(library, key),
                    searchExpanded: searchExpanded,
                    onToggleSearch: onToggleSearch,
                    onAddPlaylist: (library.csrfToken ?? token) == null ? null : () => _createPlaylist(context, ref, (library.csrfToken ?? token)!),
                  ),
                  _SearchFieldSlot(expanded: searchExpanded, controller: searchController, onChanged: onQueryChanged),
                  Expanded(
                    child: SearchLoadingGate(
                      enabled: searchExpanded,
                      loadingKey: query.trim().isEmpty ? null : query,
                      child: TabBarView(controller: controller, children: [for (final key in order) _remoteTabContent(context, ref, library, key, token)]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _remoteCount(RemoteLibrary library, String key) => switch (key) {
        'watch-later' => _filterVideos(library.watchLater, query).length,
        'favorites' => _filterVideos(library.favorites, query).length,
        'playlists' => _filterPlaylists(library.playlists, query).length,
        'subscriptions' => _filterVideos(library.subscriptions, query).length,
        _ => 0,
      };

  Widget _remoteTabContent(BuildContext context, WidgetRef ref, RemoteLibrary library, String key, String? accountToken) {
    final l10n = AppLocalizations.of(context)!;
    return switch (key) {
      'watch-later' => _SelectableVideos(
          videos: _filterVideos(library.watchLater, query),
          emptyMessage: l10n.noWatchLater,
          remover: (ref, ids) async {
            final account = ref.read(accountProvider).valueOrNull;
            final userId = account?.id;
            final token = library.csrfToken ?? accountToken;
            if (userId == null || token == null) return;
            final settings = await ref.read(settingsProvider.future);
            final repository = ref.read(han1meRepositoryProvider);
            for (final id in ids) {
              await repository.saveToPlaylist(settings.resolvedBaseUrl, token, 'save', id, false);
            }
            ref.invalidate(remoteLibraryProvider);
          },
        ),
      'favorites' => _SelectableVideos(
          videos: _filterVideos(library.favorites, query),
          emptyMessage: l10n.noFavoriteVideos,
          remover: (ref, ids) async {
            final account = ref.read(accountProvider).valueOrNull;
            final userId = account?.id;
            final token = library.csrfToken ?? accountToken;
            if (userId == null || token == null) return;
            final settings = await ref.read(settingsProvider.future);
            final repository = ref.read(han1meRepositoryProvider);
            for (final id in ids) {
              await repository.setFavorite(settings.resolvedBaseUrl, token, userId, id, false);
            }
            ref.invalidate(remoteLibraryProvider);
          },
        ),
      'playlists' => _Playlists(playlists: _filterPlaylists(library.playlists, query)),
      'subscriptions' => _RemoteSubscriptions(artists: _filterArtists(library.subscriptionArtists, query), videos: _filterVideos(library.subscriptions, query)),
      _ => _SelectableVideos(
          videos: _filterVideos(library.watchLater, query),
          emptyMessage: l10n.noWatchLater,
          remover: (ref, ids) async {
            final account = ref.read(accountProvider).valueOrNull;
            final userId = account?.id;
            final token = library.csrfToken ?? accountToken;
            if (userId == null || token == null) return;
            final settings = await ref.read(settingsProvider.future);
            final repository = ref.read(han1meRepositoryProvider);
            for (final id in ids) {
              await repository.saveToPlaylist(settings.resolvedBaseUrl, token, 'save', id, false);
            }
            ref.invalidate(remoteLibraryProvider);
          },
        ),
    };
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref, String token) async {
    final result = await showDialog<(String, String)>(context: context, builder: (_) => const _CreatePlaylistDialog());
    if (result == null || result.$1.isEmpty) return;
    final settings = await ref.read(settingsProvider.future);
    await ref.read(han1meRepositoryProvider).createPlaylist(settings.resolvedBaseUrl, token, '', result.$1, result.$2);
    ref.invalidate(remoteLibraryProvider);
  }
}

class _DrawerActionBar extends StatelessWidget {
  const _DrawerActionBar({
    required this.count,
    required this.searchExpanded,
    required this.onToggleSearch,
    required this.showPlaylistAction,
    this.onAddPlaylist,
  });

  final int count;
  final bool searchExpanded;
  final VoidCallback onToggleSearch;
  final bool showPlaylistAction;
  final VoidCallback? onAddPlaylist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(l10n.libraryItemsCount(count), style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          _PlaylistAddAction(visible: showPlaylistAction, onPressed: onAddPlaylist),
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
  }
}

class _PlaylistAddAction extends StatelessWidget {
  const _PlaylistAddAction({required this.visible, this.onPressed});

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

class _LocalSubscriptions extends StatelessWidget {
  const _LocalSubscriptions({required this.artists, required this.videos, required this.selectedArtist, required this.onSelected});

  final List<SubscribedArtist> artists;
  final Map<String, List<FollowingVideo>> videos;
  final String? selectedArtist;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = artists.any((artist) => artist.id == selectedArtist) ? selectedArtist : null;
    final allVideos = videos.values.expand((items) => items).fold(<String, FollowingVideo>{}, (items, video) => items..putIfAbsent(video.videoCode, () => video)).values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final visible = selected == null ? allVideos : videos[selected] ?? const <FollowingVideo>[];
    return _SubscriptionsView(
      artistHeader: artists.isEmpty
          ? null
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: 72),
              itemCount: artists.length,
              itemBuilder: (context, index) {
                final artist = artists[index];
                return _SubscribedArtistCard(artist: artist, selected: artist.id == selected, onTap: () => onSelected(artist.id == selected ? null : artist.id), onLongPress: () => context.push('/search', extra: SearchRouteRequest(initialUrl: Uri(path: '/search', queryParameters: {'query': artist.name}).toString())));
              },
            ),
      videos: visible,
      message: AppLocalizations.of(context)!.noSubscriptionVideos,
    );
  }
}

class _RemoteSubscriptions extends StatefulWidget {
  const _RemoteSubscriptions({required this.artists, required this.videos});

  final List<SubscribedArtist> artists;
  final List<FollowingVideo> videos;

  @override
  State<_RemoteSubscriptions> createState() => _RemoteSubscriptionsState();
}

class _RemoteSubscriptionsState extends State<_RemoteSubscriptions> {
  String? _artist;

  @override
  Widget build(BuildContext context) {
    final selected = widget.artists.any((artist) => artist.name == _artist) ? _artist : null;
    final videos = selected == null ? widget.videos : widget.videos.where((video) => video.artistName == selected).toList(growable: false);
    return _SubscriptionsView(
      artistHeader: widget.artists.isEmpty
          ? null
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: 72),
              itemCount: widget.artists.length,
              itemBuilder: (context, index) {
                final artist = widget.artists[index];
                final isSelected = artist.name == selected;
                return _SubscribedArtistCard(
                  artist: artist,
                  selected: isSelected,
                  onTap: () => setState(() => _artist = artist.name == selected ? null : artist.name),
                  onLongPress: () => context.push('/search', extra: SearchRouteRequest(initialUrl: Uri(path: '/search', queryParameters: {'query': artist.name}).toString())),
                );
              },
            ),
      videos: videos,
      message: AppLocalizations.of(context)!.noSubscriptionVideos,
    );
  }
}

class _SubscriptionsView extends StatefulWidget {
  const _SubscriptionsView({required this.artistHeader, required this.videos, required this.message});

  final Widget? artistHeader;
  final List<FollowingVideo> videos;
  final String message;

  @override
  State<_SubscriptionsView> createState() => _SubscriptionsViewState();
}

class _SubscriptionsViewState extends State<_SubscriptionsView> {
  static const _artistHeight = 252.0;

  var _collapsed = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta > 2 && !_collapsed) {
        setState(() => _collapsed = true);
      } else if (delta < -2 && _collapsed) {
        setState(() => _collapsed = false);
      }
    } else if (notification is ScrollStartNotification && notification.metrics.pixels <= 0) {
      if (_collapsed) setState(() => _collapsed = false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Column(
          children: [
            if (widget.artistHeader != null)
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.hardEdge,
                child: _collapsed
                    ? const SizedBox(width: double.infinity)
                    : SizedBox(height: _artistHeight, child: widget.artistHeader),
              ),
            Expanded(child: _Videos(videos: widget.videos, message: widget.message)),
          ],
        ),
      );
}

class _SubscribedArtistCard extends StatelessWidget {
  const _SubscribedArtistCard({required this.artist, required this.selected, required this.onTap, required this.onLongPress});

  final SubscribedArtist artist;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.secondaryContainer : theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: selected ? BorderSide(color: theme.colorScheme.primary, width: 2) : BorderSide.none),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(radius: 20, backgroundImage: artist.avatarUrl?.isNotEmpty == true ? NetworkImage(artist.avatarUrl!) : null, child: artist.avatarUrl?.isNotEmpty == true ? null : Text(artist.name.characters.first)),
              const SizedBox(height: 4),
              Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalPlaylists extends ConsumerWidget {
  const _LocalPlaylists({required this.playlists});

  final List<Playlist> playlists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (playlists.isEmpty) return LibraryEmptyState(icon: Icons.playlist_play_rounded, title: l10n.noPlaylists);
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.paddingOf(context).bottom),
      itemCount: playlists.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.45),
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return PlaylistCoverCard(
          playlist: playlist,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LocalPlaylistPage(playlistId: playlist.id))),
          onLongPress: () => _delete(context, ref, playlist),
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Playlist playlist) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePlaylist),
        content: Text(l10n.deletePlaylistConfirmation(playlist.title)),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete))],
      ),
    );
    if (confirmed != true) return;
    await ref.read(libraryProvider.notifier).deletePlaylist(playlist.id);
  }
}

class _Playlists extends StatelessWidget {
  const _Playlists({required this.playlists});

  final List<Playlist> playlists;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (playlists.isEmpty) return LibraryEmptyState(icon: Icons.playlist_play_rounded, title: l10n.noPlaylists);
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.paddingOf(context).bottom),
      itemCount: playlists.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.45),
      itemBuilder: (context, index) => _PlaylistCard(playlist: playlists[index]),
    );
  }
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog();

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.newPlaylist),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: _title, autofocus: true, decoration: InputDecoration(labelText: l10n.name)), TextField(controller: _description, decoration: InputDecoration(labelText: l10n.description))]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)), FilledButton(onPressed: () => Navigator.pop(context, (_title.text.trim(), _description.text.trim())), child: Text(l10n.create))],
    );
  }
}

class _PlaylistCard extends ConsumerWidget {
  const _PlaylistCard({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PlaylistCoverCard(
        playlist: playlist,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RemotePlaylistPage(playlist: playlist))),
        onLongPress: () => _delete(context, ref),
      );

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(l10n.deletePlaylist), content: Text(l10n.deletePlaylistConfirmation(playlist.title)), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete))]));
    final account = ref.read(accountProvider).valueOrNull;
    if (confirmed != true || account?.csrfToken == null) return;
    final settings = await ref.read(settingsProvider.future);
    await ref.read(han1meRepositoryProvider).deletePlaylist(settings.resolvedBaseUrl, account!.csrfToken!, playlist.id);
    ref.invalidate(remoteLibraryProvider);
  }
}

class _Videos extends StatelessWidget {
  const _Videos({required this.videos, required this.message});

  final List<FollowingVideo> videos;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) return LibraryEmptyState(icon: Icons.subscriptions_outlined, title: message);
    return VideoCardGrid(videos: videos.map(_videoCard).toList(growable: false));
  }
}

class _SelectableVideos extends ConsumerStatefulWidget {
  const _SelectableVideos({required this.videos, required this.emptyMessage, required this.remover});

  final List<FollowingVideo> videos;
  final String emptyMessage;
  final Future<void> Function(WidgetRef ref, Set<String> videoCodes) remover;

  @override
  ConsumerState<_SelectableVideos> createState() => _SelectableVideosState();
}

class _SelectableVideosState extends ConsumerState<_SelectableVideos> {
  final _selected = <String>{};
  var _selectionMode = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: widget.videos.isEmpty
              ? LibraryEmptyState(icon: Icons.bookmark_border_rounded, title: widget.emptyMessage)
              : VideoCardGrid(
                  videos: widget.videos.map(_videoCard).toList(growable: false),
                  itemBuilder: (context, index, video, horizontal) {
                    final selected = _selected.contains(video.id);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: selected ? BoxDecoration(border: Border.all(color: colors.primary, width: 2), borderRadius: BorderRadius.circular(12)) : const BoxDecoration(),
                          child: VideoCardTile(video: video, horizontal: horizontal, onTap: _selectionMode ? () => _toggle(video.id) : null, onLongPress: () => _startSelection(video.id)),
                        ),
                        if (selected) const Positioned(top: 6, right: 6, child: Icon(Icons.check_circle, color: Colors.white)),
                      ],
                    );
                  },
                ),
        ),
        if (_selectionMode)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Material(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.selectedItems(_selected.length))),
                      TextButton(onPressed: _exitSelection, child: Text(l10n.cancel)),
                      FilledButton(onPressed: _selected.isEmpty ? null : _deleteSelected, child: Text(l10n.delete)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _toggle(String id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));
  void _startSelection(String id) => setState(() { _selectionMode = true; _selected.add(id); });
  void _exitSelection() => setState(() { _selectionMode = false; _selected.clear(); });

  Future<void> _deleteSelected() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(l10n.delete), content: Text(l10n.selectedItems(_selected.length)), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete))]));
    if (confirmed != true || !mounted) return;
    await widget.remover(ref, _selected);
    if (mounted) setState(() { _selectionMode = false; _selected.clear(); });
  }
}

VideoCard _videoCard(FollowingVideo video) => VideoCard(id: video.videoCode, title: video.title, coverUrl: video.coverUrl ?? '', artist: video.artistName, duration: video.duration, views: video.views, rating: video.rating, uploadTime: video.uploadTime);

List<LibraryTabEntry> _tabEntries(AppLocalizations l10n, List<String> order) => [for (final key in order) LibraryTabEntry(key: key, label: _tabTitle(l10n, key))];

String _tabTitle(AppLocalizations l10n, String key) => switch (key) {
      'watch-later' => l10n.watchLater,
      'favorites' => l10n.favoriteVideos,
      'playlists' => l10n.playlists,
      'subscriptions' => l10n.subscriptions,
      'history' => l10n.watchHistory,
      _ => l10n.watchLater,
    };

List<FollowingVideo> _filterVideos(Iterable<FollowingVideo> videos, String query) {
  final value = query.trim().toLowerCase();
  if (value.isEmpty) return videos.toList(growable: false);
  return videos.where((video) => video.title.toLowerCase().contains(value) || (video.artistName ?? '').toLowerCase().contains(value)).toList(growable: false);
}

List<Playlist> _filterPlaylists(List<Playlist> playlists, String query) {
  final value = query.trim().toLowerCase();
  if (value.isEmpty) return playlists;
  return playlists.where((playlist) => playlist.title.toLowerCase().contains(value) || (playlist.description ?? '').toLowerCase().contains(value)).toList(growable: false);
}

List<SubscribedArtist> _filterArtists(List<SubscribedArtist> artists, String query) {
  final value = query.trim().toLowerCase();
  if (value.isEmpty) return artists;
  return artists.where((artist) => artist.name.toLowerCase().contains(value)).toList(growable: false);
}

Map<String, List<FollowingVideo>> _filterSubscriptionVideos(Map<String, List<FollowingVideo>> videos, String query) => {
      for (final entry in videos.entries) entry.key: _filterVideos(entry.value, query),
    };

List<FollowingVideo> _uniqueVideos(Map<String, List<FollowingVideo>> videos) => videos.values
    .expand((items) => items)
    .fold(<String, FollowingVideo>{}, (items, video) => items..putIfAbsent(video.videoCode, () => video))
    .values
    .toList(growable: false);

int _libraryTabIndex(List<String> order, String key) {
  final index = order.indexOf(key);
  if (index < 0) return 0;
  return index.clamp(0, order.length - 1).toInt();
}

String _normaliseLibraryTabKey(List<String> order, String key) => order.contains(key) ? key : 'watch-later';
