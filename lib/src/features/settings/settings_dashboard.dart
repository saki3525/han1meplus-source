import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/local/watch_repository.dart';

class SettingsDashboard extends ConsumerWidget {
  const SettingsDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ref.watch(watchProvider).valueOrNull;
    final watchedVideos = watch?.watchedVideoCount ?? 0;
    final watchCount = watch?.watchCount ?? 0;
    final hasHistory = watch?.histories.isNotEmpty ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WatchFootprintCard(watchedVideos: watchedVideos, sessions: watchCount),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ToolCard(
                    icon: Icons.history_rounded,
                    title: AppLocalizations.of(context)!.historyRecords,
                    caption: hasHistory ? AppLocalizations.of(context)!.viewWatchHistory : AppLocalizations.of(context)!.noWatchHistory,
                    onTap: () => context.push('/history'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ToolCard(
                    icon: Icons.download_rounded,
                    title: AppLocalizations.of(context)!.offlineDownloads,
                    caption: AppLocalizations.of(context)!.manageOfflineContent,
                    onTap: () => context.push('/cache'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchFootprintCard extends StatelessWidget {
  const _WatchFootprintCard({required this.watchedVideos, required this.sessions});

  final int watchedVideos;
  final int sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: colors.primaryContainer,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                M3EContainer.c4SidedCookie(
                  width: 36,
                  height: 36,
                  color: colors.primary,
                  padding: const EdgeInsets.all(9),
                  child: Icon(Icons.auto_graph_rounded, size: 18, color: colors.onPrimary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.watchFootprint,
                    style: theme.textTheme.titleSmall?.copyWith(color: colors.onPrimaryContainer, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _StatCount(value: watchedVideos, label: l10n.watchedVideos, foreground: colors.onPrimaryContainer)),
                SizedBox(
                  height: 32,
                  child: VerticalDivider(width: 24, color: colors.onPrimaryContainer.withValues(alpha: .16)),
                ),
                Expanded(child: _StatCount(value: sessions, label: l10n.watchSessions, foreground: colors.onPrimaryContainer)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCount extends StatelessWidget {
  const _StatCount({required this.value, required this.label, required this.foreground});

  final int value;
  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$value',
            style: theme.textTheme.displaySmall?.copyWith(color: foreground, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: theme.textTheme.labelMedium?.copyWith(color: foreground)),
      ],
    );
  }
}

class _ToolCard extends StatefulWidget {
  const _ToolCard({required this.icon, required this.title, required this.caption, required this.onTap});

  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback onTap;

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  static const _restRadius = 20.0;
  static const _pressedRadius = 28.0;

  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AnimatedContainer(
      duration: Duration(milliseconds: _pressed ? 160 : 320),
      curve: Curves.easeOutBack,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(_pressed ? _pressedRadius : _restRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) {
            if (_pressed != value) setState(() => _pressed = value);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, size: 24, color: colors.onSecondaryContainer),
                    const Spacer(),
                    Icon(Icons.arrow_forward_rounded, size: 20, color: colors.onSecondaryContainer),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(color: colors.onSecondaryContainer, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onSecondaryContainer, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
