import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/time.dart';
import '../data/catalog_source.dart';
import '../data/store.dart';
import '../domain/catalog.dart';
import '../domain/record.dart';
import '../services/services.dart';

/// 在 main() 裡用真的 Services 覆蓋;測試用假的。
final servicesProvider = Provider<Services>((ref) => throw UnimplementedError('servicesProvider 要在 main 覆蓋'));

final storeProvider = Provider<Store>((ref) => ref.watch(servicesProvider).store);

final catalogProvider = StreamProvider<Catalog>((ref) async* {
  final store = ref.watch(storeProvider);
  final source = CatalogSource(store);
  yield await source.load();
  await for (final _ in store.watchDatasets()) {
    yield await source.load();
  }
});

class AppSettings {
  const AppSettings(this.raw);

  final Map<String, String> raw;

  /// 週起始日預設星期一(SPEC 第 6 節)。
  bool get weekStartsMonday => raw[Keys.weekStart] != 'sunday';

  /// 預設深色模式(SPEC 第 1 節:深夜哄睡後使用)。
  ThemeMode get themeMode => switch (raw[Keys.theme]) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };

  String get themeCode => raw[Keys.theme] ?? 'dark';

  bool get syncRecords => raw[Keys.syncRecords] == '1';

  bool get syncPhotos => raw[Keys.syncPhotos] == '1';

  int? get currentBabySeq => int.tryParse(raw[Keys.currentBaby] ?? '');

  String? get policyAck => raw[Keys.policyAck];
}

final settingsProvider = StreamProvider<AppSettings>(
    (ref) => ref.watch(storeProvider).watchSettings().map(AppSettings.new));

AppSettings settingsOf(WidgetRef ref) => ref.watch(settingsProvider).value ?? const AppSettings({});

final babiesProvider = StreamProvider<List<Baby>>((ref) => ref.watch(storeProvider).watchBabies());

/// 目前選的寶寶(存在每支手機本機,不同步);沒選或選的已刪除時,用序號最小的那個。
final currentBabyProvider = Provider<Baby?>((ref) {
  final babies = ref.watch(babiesProvider).value ?? const <Baby>[];
  if (babies.isEmpty) return null;
  final seq = ref.watch(settingsProvider).value?.currentBabySeq;
  return babies.firstWhere((b) => b.seq == seq, orElse: () => babies.first);
});

final monthRecordsProvider = StreamProvider.family<List<FeedRecord>, (int, int, int)>(
    (ref, key) => ref.watch(storeProvider).watchMonth(key.$1, key.$2, key.$3));

final dayRecordsProvider = StreamProvider.family<List<FeedRecord>, (int, Day)>(
    (ref, key) => ref.watch(storeProvider).watchDay(key.$1, key.$2));

final allRecordsProvider =
    StreamProvider.family<List<FeedRecord>, int>((ref, seq) => ref.watch(storeProvider).watchAll(seq));

/// 只留這支手機認得食材與單位的紀錄(不認得的先不顯示,SPEC 第 4 節「不認得的資料」)。
List<FeedRecord> knownOnly(List<FeedRecord> records, Catalog catalog) => [
      for (final r in records)
        if (catalog.knows(foodId: r.foodId, preparedUnitId: r.preparedUnitId, eatenUnitId: r.eatenUnitId)) r,
    ];
