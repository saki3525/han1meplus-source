import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../core/app_scroll_behavior.dart';
import '../core/m3e_theme_bridge.dart';
import '../core/settings.dart';
import '../features/auth/app_lock_gate.dart';
import '../features/navigation/exit_coordinator.dart';
import '../features/settings/settings_controller.dart';
import 'app_router.dart';
import 'app_theme.dart';
import 'startup_effects.dart';

class Han1meApp extends ConsumerStatefulWidget {
  const Han1meApp({super.key});

  @override
  ConsumerState<Han1meApp> createState() => _Han1meAppState();
}

class _Han1meAppState extends ConsumerState<Han1meApp> {
  late final AppExitCoordinator _exitCoordinator;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _exitCoordinator = AppExitCoordinator();
    _appRouter = AppRouter(_exitCoordinator);
  }

  @override
  void dispose() {
    _appRouter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(settingsProvider.select((value) {
      final settings = value.valueOrNull ?? const AppSettings();
      return (
        textScale: settings.textScale,
        language: settings.language,
        materialThemeMode: settings.materialThemeMode,
        useMonetColors: settings.useMonetColors,
        themeColor: settings.themeColor,
        customThemeColor: settings.customThemeColor,
        amoledMode: settings.amoledMode,
      );
    }));
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        debugShowCheckedModeBanner: false,
        routerConfig: _appRouter.router,
        builder: (context, child) => M3EThemeBridge(
          child: AppStartupEffects(
            navigatorKey: _appRouter.navigatorKey,
            exitCoordinator: _exitCoordinator,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(theme.textScale)),
              child: AppLockGate(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
        scrollBehavior: const AppScrollBehavior(),
        locale: switch (theme.language) {
          AppLanguage.system => null,
          AppLanguage.simplifiedChinese => const Locale('zh'),
          AppLanguage.traditionalChinese => const Locale('zh', 'TW'),
          AppLanguage.english => const Locale('en'),
        },
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        themeMode: theme.materialThemeMode,
        theme: appTheme(theme.useMonetColors ? lightDynamic : null, theme.themeColor.seedColor(theme.customThemeColor)),
        darkTheme: appTheme(
          theme.useMonetColors ? darkDynamic : null,
          theme.themeColor.seedColor(theme.customThemeColor),
          brightness: Brightness.dark,
          amoled: theme.amoledMode,
        ),
      ),
    );
  }
}
