import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

class SettingsCardList extends StatelessWidget {
  const SettingsCardList({
    super.key,
    required this.children,
    this.title,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final String? title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiles = children.whereType<SettingsCardItem>().toList(growable: false);
    final content = children.where((child) => child is! SettingsCardItem).toList(growable: false);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                title!,
                style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
              ),
            ),
          if (tiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < tiles.length; index++) ...[
                    if (index > 0) const SizedBox(height: 2),
                    _SettingsCardRow(
                      first: index == 0,
                      last: index == tiles.length - 1,
                      onTap: tiles[index].tapHandler,
                      onTapAt: tiles[index].tapAtHandler,
                      child: tiles[index].buildContent(context),
                    ),
                  ],
                ],
              ),
            ),
          for (final child in content)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: child,
            ),
        ],
      ),
    );
  }
}

class SettingsCardItem extends StatelessWidget {
  const SettingsCardItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onTapAt,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final void Function(BuildContext context, Offset globalPosition)? onTapAt;
  final bool enabled;

  VoidCallback? get tapHandler {
    if (!enabled) return null;
    if (trailing case final Switch toggle) {
      final onChanged = toggle.onChanged;
      return onChanged == null ? null : () => onChanged(!toggle.value);
    }
    return onTap;
  }

  void Function(BuildContext, Offset)? get tapAtHandler => enabled ? onTapAt : null;

  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = enabled ? colors.onSurface : colors.onSurface.withValues(alpha: .38);
    final secondary = enabled ? colors.onSurfaceVariant : colors.onSurface.withValues(alpha: .38);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: subtitle == null ? 44 : 60),
        child: Row(
          children: [
            if (leading != null) _ShapedIcon(leading!),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge?.copyWith(color: foreground)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(color: secondary)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              IconTheme.merge(
                data: IconThemeData(color: secondary),
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
                  child: trailing!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => buildContent(context);
}

class SettingsSliderItem extends SettingsCardItem {
  SettingsSliderItem({
    required String title,
    String? subtitle,
    Widget? leading,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
    this.labelBuilder,
  }) : super(title: title, subtitle: subtitle, leading: leading);

  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;
  final String Function(double value)? labelBuilder;

  @override
  Widget buildContent(BuildContext context) => _SettingsSliderContent(
        title: title,
        leading: leading,
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
        labelBuilder: labelBuilder,
      );
}

class SettingsMenuItem<T> extends SettingsCardItem {
  SettingsMenuItem({
    required String title,
    String? subtitle,
    Widget? leading,
    required this.value,
    required this.options,
    required this.label,
    required this.onSelected,
    this.enabled = true,
  }) : super(
          title: title,
          subtitle: subtitle,
          leading: leading,
          enabled: enabled,
          onTapAt: enabled
              ? (context, position) => _showSettingsPopupMenu<T>(
                    context,
                    position,
                    options: options,
                    label: label,
                    onSelected: onSelected,
                  )
              : null,
        );

  final T value;
  final List<T> options;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;
  final bool enabled;

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: subtitle == null ? 44 : 60),
        child: Row(
          children: [
            if (leading != null) _ShapedIcon(leading!),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge?.copyWith(color: enabled ? colors.onSurface : colors.onSurface.withValues(alpha: .38))),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label(value), style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down_rounded, color: colors.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showSettingsPopupMenu<T>(
  BuildContext context,
  Offset globalPosition, {
  required List<T> options,
  required String Function(T value) label,
  required ValueChanged<T> onSelected,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject();
  if (overlay is! RenderBox) return;
  final local = overlay.globalToLocal(globalPosition);
  final selected = await showMenu<T>(
    context: context,
    position: RelativeRect.fromLTRB(
      local.dx,
      local.dy,
      overlay.size.width - local.dx,
      overlay.size.height - local.dy,
    ),
    items: [for (final option in options) PopupMenuItem<T>(value: option, child: Text(label(option)))],
  );
  if (selected != null) onSelected(selected);
}

class SettingsRadioItem<T> extends SettingsCardItem {
  SettingsRadioItem({
    required String title,
    Widget? leading,
    required this.value,
    required this.selected,
    required this.onSelected,
  }) : super(
          title: title,
          leading: leading,
          onTap: () => onSelected(value),
          trailing: Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
        );

  final T value;
  final bool selected;
  final ValueChanged<T> onSelected;
}

class _SettingsCardRow extends StatefulWidget {
  const _SettingsCardRow({
    required this.first,
    required this.last,
    required this.child,
    this.onTap,
    this.onTapAt,
  });

  final bool first;
  final bool last;
  final Widget child;
  final VoidCallback? onTap;
  final void Function(BuildContext context, Offset globalPosition)? onTapAt;

  @override
  State<_SettingsCardRow> createState() => _SettingsCardRowState();
}

class _SettingsCardRowState extends State<_SettingsCardRow> {
  static const _outerRadius = 28.0;
  static const _innerRadius = 4.0;

  var _pressed = false;
  Offset _tapPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final radius = BorderRadius.vertical(
      top: Radius.circular(widget.first || _pressed ? _outerRadius : _innerRadius),
      bottom: Radius.circular(widget.last || _pressed ? _outerRadius : _innerRadius),
    );
    return AnimatedPhysicalModel(
      duration: Duration(milliseconds: _pressed ? 150 : 300),
      curve: Curves.easeOutCubic,
      shape: BoxShape.rectangle,
      borderRadius: radius,
      elevation: 1,
      color: colors.surfaceContainerLow,
      shadowColor: colors.shadow,
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTapDown: (details) => _tapPosition = details.globalPosition,
          onTap: () {
            final onTapAt = widget.onTapAt;
            if (onTapAt != null) {
              onTapAt(context, _tapPosition);
              return;
            }
            widget.onTap?.call();
          },
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: widget.child,
        ),
      ),
    );
  }
}

class _ShapedIcon extends StatelessWidget {
  const _ShapedIcon(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: M3EContainer.c4SidedCookie(
        width: 40,
        height: 40,
        color: colors.secondaryContainer,
        padding: const EdgeInsets.all(10),
        child: IconTheme.merge(
          data: IconThemeData(color: colors.onSecondaryContainer, size: 20),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _SettingsSliderContent extends StatefulWidget {
  const _SettingsSliderContent({
    required this.title,
    required this.leading,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
    this.labelBuilder,
  });

  final String title;
  final Widget? leading;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;
  final String Function(double value)? labelBuilder;

  @override
  State<_SettingsSliderContent> createState() => _SettingsSliderContentState();
}

class _SettingsSliderContentState extends State<_SettingsSliderContent> {
  late double _value = widget.value;

  @override
  void didUpdateWidget(covariant _SettingsSliderContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _value) {
      setState(() => _value = widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelText = widget.labelBuilder?.call(_value) ?? widget.label;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (widget.leading != null) _ShapedIcon(widget.leading!),
              Expanded(
                child: Text(widget.title, style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurface)),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: colors.secondaryContainer, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  labelText,
                  style: theme.textTheme.labelMedium?.copyWith(color: colors.onSecondaryContainer),
                ),
              ),
            ],
          ),
          Slider(
            value: _value,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: labelText,
            onChanged: (value) => setState(() => _value = value),
            onChangeEnd: widget.onChanged,
          ),
        ],
      ),
    );
  }
}
