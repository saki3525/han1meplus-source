import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/han1me_repository.dart';
import '../../domain/models/video.dart';
import '../settings/settings_controller.dart';

final previewsProvider = FutureProvider.autoDispose.family<PreviewFeed, String>((ref, month) async {
  final cachedBaseUrl = ref.watch(settingsProvider.select((value) => value.valueOrNull?.resolvedBaseUrl));
  final baseUrl = cachedBaseUrl ?? (await ref.read(settingsProvider.future)).resolvedBaseUrl;
  return ref.watch(han1meRepositoryProvider).previews(baseUrl, month);
});

class PreviewsPage extends ConsumerStatefulWidget {
  const PreviewsPage({super.key, required this.month});

  final String month;

  @override
  ConsumerState<PreviewsPage> createState() => _PreviewsPageState();
}

class _PreviewsPageState extends ConsumerState<PreviewsPage> {
  var _selected = 0;

  @override
  void didUpdateWidget(covariant PreviewsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month) _selected = 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedMonth = _PreviewMonth.parse(widget.month);
    final result = ref.watch(previewsProvider(widget.month));
    return Scaffold(
      appBar: AppBar(
        title: Text(selectedMonth.isCurrentOrFuture ? l10n.upcomingPreviews : l10n.previews),
        actions: [
          IconButton(
            tooltip: l10n.getchuPreviews,
            onPressed: () => context.push('/previews/getchu/${widget.month}'),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: l10n.comments,
            onPressed: () => context.push('/comments/preview/${widget.month}', extra: l10n.previews),
            icon: const Icon(Icons.forum_outlined),
          ),
        ],
      ),
      body: result.when(
        loading: () => const Center(child: M3EContainedLoadingIndicator()),
        error: (error, _) => _PreviewUnavailable(
          title: l10n.previewUnavailable,
          description: l10n.previewUnavailableDescription,
          onPrevious: () => _replaceMonth(context, selectedMonth.previous),
          onRetry: () => ref.invalidate(previewsProvider(widget.month)),
        ),
        data: (feed) {
          if (feed.items.isEmpty) {
            return Column(
              children: [
                _MonthNavigation(
                  month: selectedMonth,
                  onPrevious: () => _replaceMonth(context, selectedMonth.previous),
                  onNext: selectedMonth.isCurrentOrFuture ? null : () => _replaceMonth(context, selectedMonth.next),
                  onSelect: () => _pickMonth(context, selectedMonth),
                ),
                Expanded(
                  child: _PreviewUnavailable(
                    title: l10n.noPreviews,
                    description: l10n.noPreviewsDescription,
                    onPrevious: () => _replaceMonth(context, selectedMonth.previous),
                    onRetry: () => ref.invalidate(previewsProvider(widget.month)),
                  ),
                ),
              ],
            );
          }
          final index = _selected.clamp(0, feed.items.length - 1);
          return Column(
            children: [
              _MonthNavigation(
                month: selectedMonth,
                onPrevious: () => _replaceMonth(context, selectedMonth.previous),
                onNext: selectedMonth.isCurrentOrFuture ? null : () => _replaceMonth(context, selectedMonth.next),
                onSelect: () => _pickMonth(context, selectedMonth),
              ),
              _PreviewTourRow(items: feed.items, selectedIndex: index, onSelected: (value) => setState(() => _selected = value)),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _PreviewDetail(key: ValueKey(feed.items[index].id), item: feed.items[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickMonth(BuildContext context, _PreviewMonth selectedMonth) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: selectedMonth.date,
      firstDate: DateTime(1990),
      lastDate: _PreviewMonth.current.date,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (selected != null && context.mounted) _replaceMonth(context, _PreviewMonth(selected.year, selected.month));
  }

  void _replaceMonth(BuildContext context, _PreviewMonth month) => context.replace('/previews/${month.value}');
}

class _PreviewMonth {
  const _PreviewMonth(this.year, this.month);

  final int year;
  final int month;

  static _PreviewMonth get current {
    final now = DateTime.now();
    return _PreviewMonth(now.year, now.month);
  }

  factory _PreviewMonth.parse(String value) {
    if (!RegExp(r'^\d{6}$').hasMatch(value)) return current;
    final year = int.tryParse(value.substring(0, 4));
    final month = int.tryParse(value.substring(4, 6));
    return year == null || month == null || month < 1 || month > 12 ? current : _PreviewMonth(year, month);
  }

  DateTime get date => DateTime(year, month);
  String get value => '$year${month.toString().padLeft(2, '0')}';
  String get label => '$year${month.toString().padLeft(2, '0')}';
  _PreviewMonth get previous => _fromDate(DateTime(year, month - 1));
  _PreviewMonth get next => _fromDate(DateTime(year, month + 1));
  bool get isCurrentOrFuture => date.compareTo(current.date) >= 0;

  static _PreviewMonth _fromDate(DateTime value) => _PreviewMonth(value.year, value.month);
}

class _MonthNavigation extends StatelessWidget {
  const _MonthNavigation({required this.month, required this.onPrevious, required this.onNext, required this.onSelect});

  final _PreviewMonth month;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(tooltip: l10n.previousMonth, onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: TextButton.icon(
              onPressed: onSelect,
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(l10n.previewMonth(month.label)),
            ),
          ),
          IconButton(tooltip: l10n.nextMonth, onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _PreviewTourRow extends StatefulWidget {
  const _PreviewTourRow({required this.items, required this.selectedIndex, required this.onSelected});

  final List<PreviewItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<_PreviewTourRow> createState() => _PreviewTourRowState();
}

class _PreviewTourRowState extends State<_PreviewTourRow> {
  final _controller = ScrollController();

  @override
  void didUpdateWidget(covariant _PreviewTourRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex || oldWidget.items.length != widget.items.length) _reveal();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reveal() {
    if (!_controller.hasClients) return;
    final target = (widget.selectedIndex * 102.0 - 48).clamp(0.0, _controller.position.maxScrollExtent);
    _controller.animateTo(target, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 142,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: widget.items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final selected = index == widget.selectedIndex;
          return GestureDetector(
            onTap: () => widget.onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 92,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? colors.primary : Colors.transparent, width: 3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(imageUrl: item.coverUrl, fit: BoxFit.cover, memCacheWidth: 276, fadeInDuration: Duration.zero),
                    if (selected) ColoredBox(color: colors.primary.withValues(alpha: .18)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PreviewDetail extends StatelessWidget {
  const _PreviewDetail({super.key, required this.item});

  final PreviewItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 228,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(imageUrl: item.coverUrl, fit: BoxFit.cover, alignment: Alignment.topCenter, memCacheWidth: 960, fadeInDuration: Duration.zero),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, colors.surface.withValues(alpha: .94)],
                        stops: const [.35, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((item.videoTitle ?? '').isNotEmpty)
                          Text(item.videoTitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        if (item.title.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(color: colors.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ),
                  if (item.id.isNotEmpty)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: FilledButton.tonalIcon(
                        onPressed: () => context.push('/video/${item.id}'),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(l10n.watchVideo),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((item.brand ?? '').isNotEmpty) _DetailLine(icon: Icons.business_outlined, text: item.brand!),
                  if ((item.releaseDate ?? '').isNotEmpty) _DetailLine(icon: Icons.event_outlined, text: item.releaseDate!),
                  if ((item.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(item.description!, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.5)),
                  ],
                  if (item.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final tag in item.tags) Chip(label: Text(tag), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)],
                    ),
                  ],
                  if (item.previewImages.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(l10n.previewImages(item.previewImages.length), style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 88,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: item.previewImages.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => GestureDetector(
                          onTap: () => _showPreviewImages(context, item, index),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AspectRatio(
                              aspectRatio: 3 / 2,
                              child: CachedNetworkImage(imageUrl: item.previewImages[index], fit: BoxFit.cover, memCacheWidth: 300, fadeInDuration: Duration.zero),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (item.id.isEmpty && item.brand == null && item.releaseDate == null && item.description == null)
                    Text(l10n.previewUnavailableDescription, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}

class _PreviewUnavailable extends StatelessWidget {
  const _PreviewUnavailable({required this.title, required this.description, required this.onPrevious, required this.onRetry});

  final String title;
  final String description;
  final VoidCallback onPrevious;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_outlined, size: 56),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(onPressed: onPrevious, icon: const Icon(Icons.chevron_left), label: Text(l10n.previousMonth)),
                OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(l10n.reload)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showPreviewImages(BuildContext context, PreviewItem item, int initialPage) => showDialog<void>(
      context: context,
      builder: (context) => _PreviewImagesDialog(item: item, initialPage: initialPage),
    );

class _PreviewImagesDialog extends StatefulWidget {
  const _PreviewImagesDialog({required this.item, required this.initialPage});

  final PreviewItem item;
  final int initialPage;

  @override
  State<_PreviewImagesDialog> createState() => _PreviewImagesDialogState();
}

class _PreviewImagesDialogState extends State<_PreviewImagesDialog> {
  late final _controller = PageController(initialPage: widget.initialPage);
  late var _index = widget.initialPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: Text(widget.item.videoTitle ?? widget.item.title)),
          body: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: widget.item.previewImages.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) => InteractiveViewer(
                  child: Center(child: CachedNetworkImage(imageUrl: widget.item.previewImages[index], fit: BoxFit.contain, fadeInDuration: Duration.zero)),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .7), borderRadius: BorderRadius.circular(4)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('${_index + 1} / ${widget.item.previewImages.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
