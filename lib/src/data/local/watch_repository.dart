import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/library.dart';
import 'json_store.dart';

class WatchState {
  const WatchState({
    this.continueItems = const [],
    this.histories = const [],
    this.watchedVideoCodes = const {},
  });

  final List<WatchProgress> continueItems;
  final List<WatchHistory> histories;
  final Set<String> watchedVideoCodes;

  int get watchedVideoCount => watchedVideoCodes.length;

  int get watchCount => histories.length;

  Map<String, dynamic> toJson() => {
        'continueItems': continueItems.map((item) => item.toJson()).toList(),
        'histories': histories.map((item) => item.toJson()).toList(),
        'watchedVideoCodes': watchedVideoCodes.toList(growable: false),
      };

  factory WatchState.fromJson(Map<String, dynamic> json) {
    final histories = ((json['histories'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => WatchHistory.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    final storedCodes = ((json['watchedVideoCodes'] as List?) ?? const []).whereType<String>().toSet();
    final codes = {...storedCodes, ...histories.map((item) => item.videoCode).where((code) => code.isNotEmpty)};
    return WatchState(
      continueItems: ((json['continueItems'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => WatchProgress.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      histories: histories,
      watchedVideoCodes: codes,
    );
  }
}

final watchProvider = AsyncNotifierProvider<WatchController, WatchState>(WatchController.new);

class WatchController extends AsyncNotifier<WatchState> {
  final _store = JsonStore();
  Future<void> _writeQueue = Future.value();

  @override
  Future<WatchState> build() async => WatchState.fromJson(await _store.read('watch_store.json'));

  Future<void> _save(WatchState value) async {
    await _store.write('watch_store.json', value.toJson());
    state = AsyncData(value);
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _writeQueue.then((_) => operation());
    _writeQueue = next.catchError((_) {});
    return next;
  }

  Future<void> progress({
    required String id,
    required String title,
    String? coverUrl,
    required int positionMs,
    required int durationMs,
  }) =>
      _enqueue(() async {
        final current = state.valueOrNull ?? await future;
        final item = WatchProgress(
          videoCode: id,
          title: title,
          coverUrl: coverUrl,
          positionMs: max(positionMs, 0),
          durationMs: max(durationMs, 0),
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _save(WatchState(
          continueItems: [item, ...current.continueItems.where((existing) => existing.videoCode != id)].take(6).toList(),
          histories: current.histories,
          watchedVideoCodes: current.watchedVideoCodes,
        ));
      });

  Future<void> addTime(String id, String title, int watchedMs, {String? coverUrl, String? sessionKey, String? artistName, String? duration, String? views, String? rating, String? uploadTime}) {
    if (watchedMs <= 0) return Future.value();
    return _enqueue(() async {
      final current = state.valueOrNull ?? await future;
      final now = DateTime.now();
      final date = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final histories = List<WatchHistory>.of(current.histories);
      final existingIndex = sessionKey == null ? -1 : histories.lastIndexWhere((item) => item.sessionKey == sessionKey);
      if (existingIndex >= 0) {
        final existing = histories[existingIndex];
        histories[existingIndex] = WatchHistory(
          id: existing.id,
          videoCode: existing.videoCode,
          title: title.isNotEmpty ? title : existing.title,
          watchedMs: watchedMs > existing.watchedMs ? watchedMs : existing.watchedMs,
          date: existing.date,
          createdAt: now.millisecondsSinceEpoch,
          coverUrl: coverUrl ?? existing.coverUrl,
          sessionKey: sessionKey,
          artistName: artistName ?? existing.artistName,
          duration: duration ?? existing.duration,
          views: views ?? existing.views,
          rating: rating ?? existing.rating,
          uploadTime: uploadTime ?? existing.uploadTime,
        );
      } else {
        histories.add(WatchHistory(
          id: '${now.microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}',
          videoCode: id,
          title: title,
          watchedMs: watchedMs,
          date: date,
          createdAt: now.millisecondsSinceEpoch,
          coverUrl: coverUrl,
          sessionKey: sessionKey,
          artistName: artistName,
          duration: duration,
          views: views,
          rating: rating,
          uploadTime: uploadTime,
        ));
      }
      await _save(WatchState(
        continueItems: current.continueItems,
        histories: histories.length > 500 ? histories.sublist(histories.length - 500) : histories,
        watchedVideoCodes: {...current.watchedVideoCodes, if (id.isNotEmpty) id},
      ));
    });
  }

  Future<void> deleteHistories(Set<String> ids) => _enqueue(() async {
        final current = state.valueOrNull ?? await future;
        await _save(WatchState(
          continueItems: current.continueItems,
          histories: current.histories.where((item) => !ids.contains(item.id)).toList(),
          watchedVideoCodes: current.watchedVideoCodes,
        ));
      });

  Future<void> clearHistories() => _enqueue(() async {
        final current = state.valueOrNull ?? await future;
        await _save(WatchState(
          continueItems: current.continueItems,
          histories: const [],
          watchedVideoCodes: current.watchedVideoCodes,
        ));
      });

  Future<void> replace(WatchState value) => _enqueue(() => _save(value));
}
