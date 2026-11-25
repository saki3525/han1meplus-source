import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/han1me_repository.dart';
import '../../domain/models/library.dart';
import '../account/account_controller.dart';
import '../settings/settings_controller.dart';
import '../../data/local/library_repository.dart';

final remoteLibraryProvider = FutureProvider.autoDispose<RemoteLibrary>((ref) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);
  final cachedAccountId = ref.watch(accountProvider.select((value) => value.valueOrNull?.id));
  final accountId = cachedAccountId ?? (await ref.read(accountProvider.future))?.id;
  if (accountId == null) throw StateError('Not logged in');
  final cachedBaseUrl = ref.watch(settingsProvider.select((value) => value.valueOrNull?.resolvedBaseUrl));
  final baseUrl = cachedBaseUrl ?? (await ref.read(settingsProvider.future)).resolvedBaseUrl;
  final library = await ref.watch(han1meRepositoryProvider).library(baseUrl, accountId);
  await ref.read(libraryProvider.notifier).cacheRemote(library);
  return library;
});
