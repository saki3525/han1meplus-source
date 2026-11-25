import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/han1me_repository.dart';
import '../../data/local/library_repository.dart';
import '../../data/local/watch_repository.dart';
import '../../domain/models/library.dart';
import '../../domain/models/video.dart';
import '../account/account_controller.dart';
import 'remote_library_controller.dart';
import '../settings/settings_controller.dart';
import '../shared/search_loading_gate.dart';
import '../shared/video_card.dart';
import 'library_empty_state.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _searchController = TextEditingController();
  final _selected = <String>{};
  var _query = '';
  var _editing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _toggleEditing() => setState(() {
        _editing = !_editing;
        if (!_editing) _selected.clear();
      });

  void _toggle(String key) => setState(() => _selected.contains(key) ? _selected.remove(key) : _selected.add(key));

  void _startSelection(String key) => setState(() {
        _editing = true;
        _selected.add(key);
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(accountProvider).valueOrNull;
    final signedIn = account?.id != null;
    final remote = signedIn ? ref.watch(remoteLibraryProvider) : null;
    final entries = signedIn ? _remoteEntries(remote?.valueOrNull) : _localEntries();
    final visible = _filter(entries, _query);
    final hasEntries = entries.isNotEmpty;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _editing) _toggleEditing();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.watchHistory),
          actions: [
            if (hasEntries) ...[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _editing
                    ? FilledButton.tonal(
                        key: const ValueKey('done'),
                        onPressed: _toggleEditing,
                        child: Text(l10n.done),
                      )
                    : IconButton.filledTonal(
                        key: const ValueKey('edit'),
                        tooltip: l10n.edit,
                        onPressed: _toggleEditing,
                        icon: const Icon(Icons.edit_outlined),
                      ),
              ),
              if (_editing)
                IconButton(
                  tooltip: l10n.clearAllHistory,
                  onPressed: () => _clearAll(context),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _HistorySearchBar(
                controller: _searchController,
                hint: l10n.searchWatchHistory,
                onChanged: (value) => setState(() => _query = value),
                onClear: _clearSearch,
              ),
            ),
            Expanded(
              child: SearchLoadingGate(
                loadingKey: _query.trim().isEmpty ? null : _query,
                child: _content(context, l10n, visible, remote, colors),
              ),
            ),
            if (_editing)
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
                          TextButton(onPressed: _toggleEditing, child: Text(l10n.cancel)),
                          FilledButton(onPressed: _selected.isEmpty ? null : () => _deleteSelected(visible, signedIn), child: Text(l10n.delete)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AppLocalizations l10n, List<_HistoryEntry> visible, AsyncValue<RemoteLibrary>? remote, ColorScheme colors) {
    if (visible.isEmpty && remote != null && remote.isLoading) {
      return const Center(child: M3EContainedLoadingIndicator());
    }
    if (visible.isEmpty && remote != null && remote.hasError) {
      return Center(child: FilledButton(onPressed: () => ref.invalidate(remoteLibraryProvider), child: Text(l10n.reload)));
    }
    if (visible.isEmpty) {
      return LibraryEmptyState(
        icon: _query.trim().isEmpty ? Icons.history_rounded : Icons.search_off_rounded,
        title: _query.trim().isEmpty ? l10n.noWatchHistory : l10n.noSearchResults,
      );
    }
    return VideoCardGrid(
      videos: visible.map((entry) => entry.video).toList(growable: false),
      itemBuilder: (context, index, video, horizontal) {
        final entry = visible[index];
        final selected = _selected.contains(entry.key);
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: selected ? BoxDecoration(border: Border.all(color: colors.primary, width: 2), borderRadius: BorderRadius.circular(12)) : const BoxDecoration(),
              child: VideoCardTile(
                video: video,
                horizontal: horizontal,
                onTap: _editing ? () => _toggle(entry.key) : null,
                onLongPress: () => _startSelection(entry.key),
              ),
            ),
            if (selected) const Positioned(top: 6, right: 6, child: Icon(Icons.check_circle, color: Colors.white)),
          ],
        );
      },
    );
  }

  List<_HistoryEntry> _localEntries() {
    final watch = ref.watch(watchProvider).valueOrNull;
    final items = watch?.histories ?? const <WatchHistory>[];
    final library = ref.watch(libraryProvider).valueOrNull;
    final fallback = _fallbackVideos(library);
    return items.reversed.map((item) {
      final known = fallback[item.videoCode];
      return _HistoryEntry(
        key: item.id,
        videoCode: item.videoCode,
        video: VideoCard(
          id: item.videoCode,
          title: item.title.isNotEmpty ? item.title : (known?.title ?? ''),
          coverUrl: item.coverUrl ?? known?.coverUrl ?? '',
          artist: item.artistName ?? known?.artistName,
          duration: item.duration ?? known?.duration,
          views: item.views ?? known?.views,
          rating: item.rating ?? known?.rating,
          uploadTime: item.uploadTime ?? known?.uploadTime,
        ),
      );
    }).toList(growable: false);
  }

  List<_HistoryEntry> _remoteEntries(RemoteLibrary? library) {
    final items = library?.history ?? const <FollowingVideo>[];
    return [
      for (final (index, item) in items.indexed)
        _HistoryEntry(
          key: '${item.videoCode}-$index',
          videoCode: item.videoCode,
          video: VideoCard(
            id: item.videoCode,
            title: item.title,
            coverUrl: item.coverUrl ?? '',
            artist: item.artistName,
            duration: item.duration,
            views: item.views,
            rating: item.rating,
            uploadTime: item.uploadTime,
          ),
        ),
    ];
  }

  Map<String, FollowingVideo> _fallbackVideos(LibraryState? library) {
    if (library == null) return const {};
    return <String, FollowingVideo>{
      for (final video in [...library.watchLater, ...library.favorites]) video.videoCode: video,
      for (final playlist in library.playlists)
        for (final video in playlist.videos) video.videoCode: video,
    };
  }

  List<_HistoryEntry> _filter(List<_HistoryEntry> entries, String query) {
    final value = query.trim().toLowerCase();
    if (value.isEmpty) return entries;
    return entries.where((entry) => entry.video.title.toLowerCase().contains(value) || entry.videoCode.toLowerCase().contains(value)).toList(growable: false);
  }

  Future<void> _deleteSelected(List<_HistoryEntry> visible, bool signedIn) async {
    final keys = {..._selected};
    final targets = visible.where((entry) => keys.contains(entry.key)).toList(growable: false);
    if (signedIn) {
      await _deleteRemote(targets.map((entry) => entry.videoCode).toSet());
    } else {
      await ref.read(watchProvider.notifier).deleteHistories(targets.map((entry) => entry.key).toSet());
    }
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _editing = false;
    });
  }

  Future<void> _deleteRemote(Set<String> videoCodes) async {
    final account = ref.read(accountProvider).valueOrNull;
    final token = ref.read(remoteLibraryProvider).valueOrNull?.csrfToken ?? account?.csrfToken;
    if (token == null) return;
    final settings = await ref.read(settingsProvider.future);
    final repository = ref.read(han1meRepositoryProvider);
    for (final code in videoCodes) {
      await repository.deleteHistory(settings.resolvedBaseUrl, token, code);
    }
    ref.invalidate(remoteLibraryProvider);
  }

  Future<void> _clearAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_sweep_outlined),
        title: Text(l10n.clearAllHistory),
        content: Text(l10n.clearAllHistoryConfirmation),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final signedIn = ref.read(accountProvider).valueOrNull?.id != null;
    if (signedIn) {
      final remote = ref.read(remoteLibraryProvider).valueOrNull;
      await _deleteRemote((remote?.history ?? const <FollowingVideo>[]).map((entry) => entry.videoCode).toSet());
    } else {
      await ref.read(watchProvider.notifier).clearHistories();
    }
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _editing = false;
    });
  }
}

class _HistoryEntry {
  const _HistoryEntry({required this.key, required this.videoCode, required this.video});

  final String key;
  final String videoCode;
  final VideoCard video;
}

class _HistorySearchBar extends StatelessWidget {
  const _HistorySearchBar({required this.controller, required this.hint, required this.onChanged, required this.onClear});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const border = OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(28)), borderSide: BorderSide.none);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(tooltip: AppLocalizations.of(context)!.clearSearch, onPressed: onClear, icon: const Icon(Icons.close_rounded)),
          filled: true,
          fillColor: colors.surfaceContainerHigh,
          constraints: const BoxConstraints(minHeight: 56),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(borderSide: BorderSide(color: colors.primary, width: 2)),
        ),
        onChanged: onChanged,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }
}
