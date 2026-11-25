import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/log.dart';
import '../domain/catalog.dart';
import '../domain/dataset_rules.dart';
import 'store.dart';

/// [CatalogSource.apply] 的結果。
enum DatasetApply {
  /// 存起來了,之後就用這份。
  applied,

  /// App 不支援這個資料格式,沒有存。
  unsupported,

  /// 內容不合規則(DatasetRules),沒有存,繼續用手機上的那份。
  rejected,
}

/// 公用資料從哪裡來:下載過的(存在資料庫)或 App 內建的初始檔,用版本比較新的那一份。
///
/// 內建檔在 assets/datasets/,和後端第一次建表的種子資料是同一份。發版習慣:更新公用資料後,下一次發版就把內建檔換成最新的。
class CatalogSource {
  CatalogSource(this.store, {Future<String> Function(String)? loadAsset})
      : _loadAsset = loadAsset ?? rootBundle.loadString;

  final Store store;
  final Future<String> Function(String) _loadAsset;

  Future<DatasetEnvelope> builtIn(String name) async =>
      DatasetEnvelope.fromJson(jsonDecode(await _loadAsset('assets/datasets/$name.json')) as Map<String, dynamic>);

  Future<DatasetEnvelope> current(String name) async {
    final bundled = await builtIn(name);
    final saved = await store.getDataset(name);
    final supported = supportedDatasetFormats[name] ?? const [];
    if (saved == null || !supported.contains(saved.formatVersion)) return bundled;
    // 存起來的那份也要合規則:加上這個檢查之前的版本,可能存過不合規則的內容。
    // 不合就先用內建的;下一次每日檢查送出內建的版本,就會拿到最新的內容。
    final problems = DatasetRules.problems(saved);
    if (problems.isNotEmpty) {
      AppLog.warn('catalog.saved_invalid', {'dataset': name, 'problem': problems.first, 'n': problems.length});
      return bundled;
    }
    // 版本號是發布時間(年月日時分秒),字串比較就是時間比較。
    return saved.version.compareTo(bundled.version) >= 0 ? saved : bundled;
  }

  Future<Catalog> load() async => Catalog.fromEnvelopes(await current('food_list'), await current('units'));

  /// 每日檢查拿到新資料時呼叫。只存 App 支援的格式,而且內容要合規則(和手機上目前用的那份比:
  /// 版本較新、ID 都還在);不合就不存,繼續用手機上的那份。
  Future<DatasetApply> apply(DatasetEnvelope env) async {
    if (!(supportedDatasetFormats[env.name] ?? const []).contains(env.formatVersion)) return DatasetApply.unsupported;
    final problems = DatasetRules.problems(env, previous: await current(env.name));
    if (problems.isNotEmpty) {
      AppLog.warn('catalog.rejected', {'dataset': env.name, 'problem': problems.first, 'n': problems.length});
      return DatasetApply.rejected;
    }
    await store.putDataset(env);
    return DatasetApply.applied;
  }
}
