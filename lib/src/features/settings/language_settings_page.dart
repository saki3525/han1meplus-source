import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/settings.dart';
import 'settings_card_list.dart';
import 'settings_controller.dart';

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(settingsProvider).valueOrNull?.language ?? AppLanguage.system;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageSettings)),
      body: ListView(
        padding: EdgeInsets.only(top: 8, bottom: 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          SettingsCardList(title: l10n.languageSettings, children: [
            SettingsRadioItem(title: l10n.systemDefault, value: AppLanguage.system, selected: current == AppLanguage.system, onSelected: (value) => _select(ref, value)),
            SettingsRadioItem(title: l10n.simplifiedChinese, value: AppLanguage.simplifiedChinese, selected: current == AppLanguage.simplifiedChinese, onSelected: (value) => _select(ref, value)),
            SettingsRadioItem(title: l10n.traditionalChinese, value: AppLanguage.traditionalChinese, selected: current == AppLanguage.traditionalChinese, onSelected: (value) => _select(ref, value)),
            SettingsRadioItem(title: l10n.english, value: AppLanguage.english, selected: current == AppLanguage.english, onSelected: (value) => _select(ref, value)),
          ]),
        ],
      ),
    );
  }

  void _select(WidgetRef ref, AppLanguage value) {
    ref.read(settingsProvider.notifier).saveChanges((settings) => settings.copyWith(language: value));
  }
}
