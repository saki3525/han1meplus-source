import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/han1me_repository.dart';
import '../../domain/models/video.dart';
import '../settings/settings_controller.dart';
import '../account/account_controller.dart';
final commentsProvider = FutureProvider.autoDispose.family<CommentPage, String>((ref, id) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 10), link.close);
  ref.onDispose(timer.cancel);
  ref.watch(accountProvider);
  final cachedBaseUrl = ref.watch(settingsProvider.select((value) => value.valueOrNull?.resolvedBaseUrl));
  final baseUrl = cachedBaseUrl ?? (await ref.read(settingsProvider.future)).resolvedBaseUrl;
  return ref.read(han1meRepositoryProvider).comments(baseUrl, id);
});
