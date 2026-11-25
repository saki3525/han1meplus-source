import 'dart:async';

import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/assets/search_option_catalog.dart';
import '../../domain/models/search_query.dart';
import '../../domain/models/video.dart';
import '../settings/settings_controller.dart';
import '../shared/compact_video_card.dart';
import '../shared/search_loading_gate.dart';
import '../shared/video_card.dart';
import 'search_controller.dart';

const _compactSearchGenres = {'裏番', '泡麵番'};

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, required this.request});

  final SearchRouteRequest request;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final query = ref.read(searchQueryProvider(widget.request));
    _textController.text = query.text;
    if (query.hasSearchCriteria) unawaited(ref.read(searchHistoryProvider.notifier).record(query));
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request == widget.request) return;
    _textController.text = ref.read(searchQueryProvider(widget.request)).text;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _writeText(String value) {
    _textController.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
  }

  void _openResult(VideoCard video) {
    if (video.id.isNotEmpty) {
      context.push('/video/${video.id}');
      return;
    }
    final query = (video.artistQuery ?? video.uploadTime ?? '').trim();
    if (query.isEmpty) return;
    final notifier = ref.read(searchQueryProvider(widget.request).notifier);
    notifier.artist(query);
    _writeText(query);
  }

  void _submit(String value) {
    FocusScope.of(context).unfocus();
    final notifier = ref.read(searchQueryProvider(widget.request).notifier);
    notifier.text(value.trim());
    final next = ref.read(searchQueryProvider(widget.request));
    unawaited(ref.read(searchHistoryProvider.notifier).record(next));
  }

  Future<void> _showFilters() async {
    FocusScope.of(context).unfocus();
    final options = ref.read(searchOptionCatalogProvider).valueOrNull;
    if (options == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _FilterSheet(request: widget.request, options: options),
    );
  }

  void _applyHistory(SearchQuery query) {
    ref.read(searchQueryProvider(widget.request).notifier).replace(query);
    _writeText(query.text);
    unawaited(ref.read(searchHistoryProvider.notifier).record(query));
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final query = ref.watch(searchQueryProvider(request));
    final options = ref.watch(searchOptionCatalogProvider).valueOrNull;
    final l10n = AppLocalizations.of(context)!;
    final hasQuery = query.hasSearchCriteria;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back)),
                  Expanded(
                    child: _SearchField(
                      controller: _textController,
                      hint: l10n.searchHint,
                      onSubmitted: _submit,
                      onClear: () {
                        _textController.clear();
                        ref.read(searchQueryProvider(request).notifier).reset();
                      },
                      onFilters: options == null ? null : _showFilters,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: hasQuery
                  ? _Results(request: request, query: query, options: options, onOpen: _openResult)
                  : _Discovery(request: request, onHistory: _applyHistory, onFilters: options == null ? null : _showFilters),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint, required this.onSubmitted, required this.onClear, this.onFilters});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback? onFilters;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => SearchBar(
        controller: controller,
        hintText: hint,
        textInputAction: TextInputAction.search,
        constraints: const BoxConstraints(minHeight: 56),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
        leading: IconButton(tooltip: AppLocalizations.of(context)!.searchHint, onPressed: () => onSubmitted(controller.text), icon: const Icon(Icons.search_rounded)),
        trailing: [
          if (value.text.isNotEmpty)
            IconButton(tooltip: AppLocalizations.of(context)!.clearSearch, onPressed: onClear, icon: const Icon(Icons.close_rounded)),
          IconButton(tooltip: AppLocalizations.of(context)!.filters, onPressed: onFilters, icon: const Icon(Icons.tune_rounded)),
        ],
        onSubmitted: onSubmitted,
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.request, required this.query, required this.options, required this.onOpen});

  final SearchRouteRequest request;
  final SearchQuery query;
  final SearchOptionCatalog? options;
  final ValueChanged<VideoCard> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final result = ref.watch(searchFeedProvider(request));
    final useCompactCards = ref.watch(settingsProvider.select((value) => value.valueOrNull?.useCompactSearchCards ?? true)) &&
        _compactSearchGenres.contains(options?.genres.canonical(query.genre) ?? query.genre);
    return SearchLoadingGate(
      loadingKey: query.copyWith(page: 1).toUri().toString(),
      child: result.when(
        loading: () => const Center(child: M3EContainedLoadingIndicator()),
        error: (error, stackTrace) => _ErrorView(error: error, onRetry: () => ref.invalidate(searchFeedProvider(request))),
        data: (feed) {
          if (feed.items.isEmpty) return _EmptyState(message: l10n.noSearchResults);
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 480) {
                unawaited(ref.read(searchFeedProvider(request).notifier).loadMore());
              }
              return false;
            },
            child: Column(
              children: [
                Expanded(
                  child: useCompactCards
                      ? CompactVideoCardGrid(
                          videos: feed.items,
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          itemBuilder: (context, index, video) => CompactVideoCard(video: video, onTap: () => onOpen(video)),
                        )
                      : VideoCardGrid(
                          videos: feed.items,
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          itemBuilder: (context, index, video, horizontal) => VideoCardTile(video: video, horizontal: horizontal, onTap: () => onOpen(video)),
                        ),
                ),
                if (feed.loadingMore)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12 + MediaQuery.paddingOf(context).bottom),
                    child: const M3EContainedLoadingIndicator(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Discovery extends ConsumerWidget {
  const _Discovery({required this.request, required this.onHistory, this.onFilters});

  final SearchRouteRequest request;
  final ValueChanged<SearchQuery> onHistory;
  final VoidCallback? onFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final histories = ref.watch(searchHistoryProvider).valueOrNull ?? const <SearchQuery>[];
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        Material(
          type: MaterialType.transparency,
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const Icon(Icons.tune_rounded),
            title: Text(l10n.filters),
            subtitle: Text(l10n.searchHint),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onFilters,
          ),
        ),
        if (histories.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: Row(
              children: [
                Expanded(child: Text(l10n.searchHistory, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
                TextButton(
                  onPressed: () => ref.read(searchHistoryProvider.notifier).clear(),
                  child: Text(l10n.clear),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          for (final item in histories) ...[
            _HistoryTile(
              label: _historyLabel(l10n, item),
              filters: _historyFilters(l10n, item),
              onTap: () => onHistory(item),
              onDelete: () => ref.read(searchHistoryProvider.notifier).remove(item),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ],
    );
  }

  String _historyLabel(AppLocalizations l10n, SearchQuery query) {
    if (query.text.trim().isNotEmpty) return query.text.trim();
    if (query.tags.isNotEmpty) return l10n.searchHistoryTags(query.tags.length);
    if (query.genre.isNotEmpty) return query.genre;
    return l10n.searchHistoryAll;
  }

  String _historyFilters(AppLocalizations l10n, SearchQuery query) {
    final parts = <String>[
      if (query.genre.isNotEmpty) query.genre,
      if (query.sort.isNotEmpty) query.sort,
      if (query.date.isNotEmpty) query.date,
      if (query.duration.isNotEmpty) query.duration,
      if (query.tags.isNotEmpty) l10n.searchHistoryTags(query.tags.length),
      if (query.type.isNotEmpty) l10n.searchAuthors,
    ];
    return parts.join(' · ');
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.label, required this.filters, required this.onTap, required this.onDelete});

  final String label;
  final String filters;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
          child: Row(
            children: [
              Icon(Icons.history_rounded, size: 20, color: colors.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge),
                    if (filters.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(filters, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context)!.deleteSearchHistory,
                onPressed: onDelete,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({required this.request, required this.options});

  final SearchRouteRequest request;
  final SearchOptionCatalog options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final query = ref.watch(searchQueryProvider(request));
    final notifier = ref.read(searchQueryProvider(request).notifier);
    final locale = searchOptionLocaleKey(Localizations.localeOf(context));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.filters, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MenuFilterButton(
                    label: l10n.category(query.genre.isEmpty ? l10n.all : options.genres.localize(query.genre, locale) ?? query.genre),
                    icon: Icons.category_outlined,
                    values: options.genres.options.map((item) => item.searchKey ?? '').toList(),
                    onSelected: notifier.genre,
                    formatter: (value) => value.isEmpty ? l10n.all : options.genres.localize(value, locale) ?? value,
                  ),
                  _MenuFilterButton(
                    label: l10n.sort(query.sort.isEmpty ? l10n.defaultValue : options.sorts.localize(query.sort, locale) ?? query.sort),
                    icon: Icons.sort,
                    values: options.sorts.options.map((item) => item.searchKey ?? '').toList(),
                    onSelected: notifier.sort,
                    formatter: (value) => value.isEmpty ? l10n.defaultValue : options.sorts.localize(value, locale) ?? value,
                  ),
                  _ActionFilterButton(
                    label: l10n.releaseDate(query.date.isEmpty ? l10n.all : options.releaseDates.localize(query.date, locale) ?? query.date),
                    icon: Icons.calendar_month_outlined,
                    onPressed: () async {
                      final date = await _showDateFilter(context, query.date, options.releaseDates.options, locale);
                      if (date != null) notifier.date(date);
                    },
                  ),
                  _ActionFilterButton(
                    label: query.tags.isEmpty ? l10n.tags : l10n.tagsSelected(query.tags.length),
                    icon: Icons.sell_outlined,
                    onPressed: () async {
                      final selection = await _showTagFilter(context, query.tags, query.broad, options, locale);
                      if (selection != null) notifier.tags(selection.tags, selection.broad);
                    },
                  ),
                  _MenuFilterButton(
                    label: l10n.duration(query.duration.isEmpty ? l10n.all : options.durations.localize(query.duration, locale) ?? query.duration),
                    icon: Icons.schedule_outlined,
                    values: options.durations.options.map((item) => item.searchKey ?? '').toList(),
                    onSelected: notifier.duration,
                    formatter: (value) => value.isEmpty ? l10n.all : options.durations.localize(value, locale) ?? value,
                  ),
                  _ActionFilterButton(
                    label: l10n.searchAuthors,
                    icon: Icons.person_search_outlined,
                    selected: query.type == 'artist',
                    onPressed: () => notifier.type(query.type == 'artist' ? '' : 'artist'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.done)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuFilterButton extends StatelessWidget {
  const _MenuFilterButton({required this.label, required this.icon, required this.values, required this.onSelected, required this.formatter});

  final String label;
  final IconData icon;
  final List<String> values;
  final ValueChanged<String> onSelected;
  final String Function(String) formatter;

  @override
  Widget build(BuildContext context) => MenuAnchor(
        menuChildren: values.map((value) => MenuItemButton(onPressed: () => onSelected(value), child: Text(formatter(value)))).toList(growable: false),
        builder: (context, controller, child) => FilledButton.tonalIcon(
          onPressed: controller.open,
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
      );
}

class _ActionFilterButton extends StatelessWidget {
  const _ActionFilterButton({required this.label, required this.icon, required this.onPressed, this.selected = false});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => selected
      ? FilledButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label))
      : FilledButton.tonalIcon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label));
}

enum _DateMode { range, month }

Future<String?> _showDateFilter(BuildContext context, String currentDate, List<SearchOption> options, String locale) => showDialog<String>(
      context: context,
      builder: (context) => _DateFilterDialog(currentDate: currentDate, options: options, locale: locale),
    );

class _DateFilterDialog extends StatefulWidget {
  const _DateFilterDialog({required this.currentDate, required this.options, required this.locale});

  final String currentDate;
  final List<SearchOption> options;
  final String locale;

  @override
  State<_DateFilterDialog> createState() => _DateFilterDialogState();
}

class _DateFilterDialogState extends State<_DateFilterDialog> {
  _DateMode _mode = _DateMode.range;
  String _range = '';
  String _year = '';
  String _month = '';

  @override
  void initState() {
    super.initState();
    if (widget.options.map((item) => item.searchKey).contains(widget.currentDate)) {
      _range = widget.currentDate;
    } else if (widget.currentDate.isNotEmpty) {
      final values = widget.currentDate.split(' ');
      _year = values.take(2).join(' ');
      _month = values.length > 2 ? values.skip(2).take(2).join(' ') : '';
      _mode = _DateMode.month;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final years = [for (var year = DateTime.now().year; year >= 1990; year--) '$year 年'];
    return AlertDialog(
      title: Text(l10n.releaseDateTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<_DateMode>(
              segments: [
                ButtonSegment(value: _DateMode.range, label: Text(l10n.dateRange)),
                ButtonSegment(value: _DateMode.month, label: Text(l10n.specificYearMonth)),
              ],
              selected: {_mode},
              onSelectionChanged: (value) => setState(() => _mode = value.first),
            ),
            const SizedBox(height: 16),
            if (_mode == _DateMode.range)
              DropdownButtonFormField<String>(
                value: _range,
                decoration: InputDecoration(labelText: l10n.releaseDateTitle),
                items: widget.options.map((item) => DropdownMenuItem(value: item.searchKey ?? '', child: Text((item.searchKey?.isEmpty ?? true) ? l10n.all : item.labelFor(widget.locale)))).toList(),
                onChanged: (value) => setState(() => _range = value ?? ''),
              )
            else
              Row(
                children: [
                  Expanded(child: DropdownButtonFormField(value: _year, decoration: InputDecoration(labelText: l10n.year), items: ['', ...years].map((value) => DropdownMenuItem(value: value, child: Text(value.isEmpty ? l10n.allYears : value))).toList(), onChanged: (value) => setState(() => _year = value ?? ''))),
                  const SizedBox(width: 12),
                  Expanded(child: DropdownButtonFormField(value: _month, decoration: InputDecoration(labelText: l10n.month), items: [for (var month = 1; month <= 12; month++) '$month 月', ''].map((value) => DropdownMenuItem(value: value, child: Text(value.isEmpty ? l10n.allMonths : value))).toList(), onChanged: (value) => setState(() => _month = value ?? ''))),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _mode == _DateMode.range ? _range : [_year, _month].where((value) => value.isNotEmpty).join(' ')), child: Text(l10n.apply)),
      ],
    );
  }
}

class _TagSelection {
  const _TagSelection(this.tags, this.broad);

  final List<String> tags;
  final bool broad;
}

Future<_TagSelection?> _showTagFilter(BuildContext context, List<String> selectedTags, bool broad, SearchOptionCatalog catalog, String locale) => showDialog<_TagSelection>(
      context: context,
      builder: (context) => _TagFilterDialog(selectedTags: selectedTags, broad: broad, catalog: catalog, locale: locale),
    );

class _TagFilterDialog extends StatefulWidget {
  const _TagFilterDialog({required this.selectedTags, required this.broad, required this.catalog, required this.locale});

  final List<String> selectedTags;
  final bool broad;
  final SearchOptionCatalog catalog;
  final String locale;

  @override
  State<_TagFilterDialog> createState() => _TagFilterDialogState();
}

class _TagFilterDialogState extends State<_TagFilterDialog> with SingleTickerProviderStateMixin {
  late final Set<String> _selected;
  late final TabController _tabController;
  late bool _broad;
  late String _group;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedTags.map(widget.catalog.canonicalTag).toSet();
    _broad = widget.broad;
    _group = widget.catalog.tags.keys.first;
    _tabController = TabController(length: widget.catalog.tags.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.tags),
      content: SizedBox(
        width: 560,
        height: 520,
        child: Column(
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.broadMatch),
              subtitle: Text(l10n.broadMatchDescription),
              value: _broad,
              onChanged: (value) => setState(() => _broad = value),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: widget.catalog.tags.keys.map((group) => Tab(text: _tagGroupLabel(l10n, group))).toList(growable: false),
              onTap: (index) => setState(() => _group = widget.catalog.tags.keys.elementAt(index)),
            ),
            Expanded(
              child: ListView(
                children: [
                  _TagGroup(
                    tags: widget.catalog.tags[_group]!.options,
                    locale: widget.locale,
                    selected: _selected,
                    onChanged: (tag, selected) {
                      setState(() {
                        if (selected) {
                          _selected.add(tag);
                        } else {
                          _selected.remove(tag);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _TagSelection(_selected.toList()..sort(), _broad)), child: Text(l10n.apply)),
      ],
    );
  }
}

class _TagGroup extends StatelessWidget {
  const _TagGroup({required this.tags, required this.locale, required this.selected, required this.onChanged});

  final List<SearchOption> tags;
  final String locale;
  final Set<String> selected;
  final void Function(String tag, bool selected) onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => FilterChip(label: Text(tag.labelFor(locale)), selected: selected.contains(tag.searchKey), onSelected: (value) => onChanged(tag.searchKey ?? '', value))).toList(),
            ),
          ],
        ),
      );
}

String _tagGroupLabel(AppLocalizations l10n, String group) => switch (group) {
  'video_attributes' => l10n.tagVideoAttributes,
  'character_relationships' => l10n.tagRelationships,
  'characteristics' => l10n.tagCharacterSettings,
  'appearance_and_figure' => l10n.tagAppearance,
  'story_location' => l10n.tagSettings,
  'story_plot' => l10n.tagStory,
  'sex_positions' => l10n.tagPositions,
  _ => group,
};

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 56),
              const SizedBox(height: 12),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: Text(AppLocalizations.of(context)!.retry)),
            ],
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 56),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
}
