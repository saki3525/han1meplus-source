import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/app_shell.dart';
import 'settings_controller.dart';
import 'settings_card_list.dart';
import 'settings_dashboard.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final drawerMode = ref.watch(settingsProvider.select((value) => value.valueOrNull?.useNavigationDrawer ?? false));
    return Scaffold(
      appBar: AppBar(leading: drawerMode ? (permanentNavigationDrawer(context) ? null : IconButton(onPressed: openAppDrawer, icon: const Icon(Icons.menu))) : null, title: Text(l10n.settings)),
      body: ListView(
        padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          const SettingsDashboard(),
          SettingsCardList(title: l10n.appearance, children: [
            _NavigationTile(icon: Icons.palette_outlined, title: l10n.themeAndColor, onTap: () => context.push('/settings/theme')),
            _NavigationTile(icon: Icons.dashboard_customize_outlined, title: l10n.interfaceLayout, onTap: () => context.push('/settings/layout')),
          ]),
          const SizedBox(height: 16),
          SettingsCardList(title: l10n.playback, children: [
            _NavigationTile(icon: Icons.smart_display_outlined, title: l10n.playbackSettings, onTap: () => context.push('/settings/playback')),
          ]),
          const SizedBox(height: 16),
          SettingsCardList(title: l10n.network, children: [
            _NavigationTile(icon: Icons.language_outlined, title: l10n.networkSettings, onTap: () => context.push('/settings/network')),
            _NavigationTile(icon: Icons.cloud_sync_outlined, title: l10n.webDavSettings, onTap: () => context.push('/settings/webdav')),
          ]),
          const SizedBox(height: 16),
          SettingsCardList(title: l10n.content, children: [
            _NavigationTile(icon: Icons.forum_outlined, title: l10n.commentSettings, onTap: () => context.push('/settings/comments')),
            _NavigationTile(icon: Icons.language_outlined, title: l10n.languageSettings, onTap: () => context.push('/settings/language')),
          ]),
          const SizedBox(height: 16),
          SettingsCardList(title: l10n.application, children: [
            _NavigationTile(icon: Icons.apps_outlined, title: l10n.applicationSettings, onTap: () => context.push('/settings/application')),
            _NavigationTile(icon: Icons.download_outlined, title: l10n.downloadSettings, onTap: () => context.push('/settings/download')),
          ]),
          const SizedBox(height: 16),
          SettingsCardList(title: l10n.other, children: [
            _NavigationTile(icon: Icons.info_outline, title: l10n.about, onTap: () => context.push('/settings/about')),
          ]),
        ],
      ),
    );
  }
}

class _NavigationTile extends SettingsCardItem {
  _NavigationTile({required IconData icon, required String title, String? subtitle, required VoidCallback onTap})
      : super(title: title, subtitle: subtitle, leading: Icon(icon), trailing: const Icon(Icons.chevron_right), onTap: onTap);
}
