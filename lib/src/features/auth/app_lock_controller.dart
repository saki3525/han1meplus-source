import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform_service.dart';
import '../settings/settings_controller.dart';

enum AppLockStatus { unlocking, locked, unlocked }

final appLockProvider = NotifierProvider<AppLockController, AppLockStatus>(AppLockController.new);

class AppLockController extends Notifier<AppLockStatus> {
  var _everUnlocked = false;
  var _authenticating = false;

  @override
  AppLockStatus build() {
    final enabled = ref.watch(settingsProvider.select((value) => value.valueOrNull?.appLockEnabled));
    if (enabled == null) return AppLockStatus.unlocking;
    if (_everUnlocked || !enabled || PlatformService.isDesktop) {
      _everUnlocked = true;
      return AppLockStatus.unlocked;
    }
    return AppLockStatus.locked;
  }

  void markUnlocked() => _everUnlocked = true;

  Future<void> unlock() async {
    if (_authenticating) return;
    _authenticating = true;
    try {
      final ok = await PlatformService.authenticate();
      if (ok) _everUnlocked = true;
      state = ok ? AppLockStatus.unlocked : AppLockStatus.locked;
    } catch (_) {
      state = AppLockStatus.locked;
    } finally {
      _authenticating = false;
    }
  }

  Future<void> retry() => unlock();
}
