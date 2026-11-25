import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            M3EContainer.c4SidedCookie(
              width: 88,
              height: 88,
              color: colors.secondaryContainer,
              padding: const EdgeInsets.all(22),
              child: IconTheme.merge(
                data: IconThemeData(color: colors.onSecondaryContainer, size: 38),
                child: Center(child: Icon(icon)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: colors.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
