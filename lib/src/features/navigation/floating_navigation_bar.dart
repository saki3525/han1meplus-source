import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

class FloatingNavigationDestination {
  const FloatingNavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class FloatingNavigationBar extends StatelessWidget {
  const FloatingNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final List<FloatingNavigationDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  static const _outerPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = M3EFloatingToolbarDefaults.standardColors(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_outerPadding, 0, _outerPadding, _outerPadding),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: M3EHorizontalFloatingToolbar(
            expanded: true,
            alignment: Alignment.bottomCenter,
            decoration: M3EFloatingToolbarDecoration(colors: colors),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < destinations.length; index++)
                  _NavigationDestinationTile(
                    destination: destinations[index],
                    selected: index == selectedIndex,
                    onTap: () => onDestinationSelected(index),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationDestinationTile extends StatelessWidget {
  const _NavigationDestinationTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  static const _collapsedWidth = 48.0;
  static const _expandedWidth = 104.0;
  static const _height = 48.0;
  static const _radius = 24.0;

  final FloatingNavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: selected ? _expandedWidth : _collapsedWidth,
        height: _height,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(_radius),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(_radius),
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? destination.selectedIcon : destination.icon, size: 22, color: foreground),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
