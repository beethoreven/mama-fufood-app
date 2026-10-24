import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/catalog.dart';
import 'store.dart';

/// 公用資料從哪裡來:下載過的(存在資料庫)或 App 內建的初始檔,用版本比較新的那一份。
///
/// 內建檔在 assets/datasets/,和後端第一次建表的種子資料是同一份
/// (tools/build_seed.py 產生)。發版習慣:更新公用資料後,下一次發版就把內建檔換成最新的。
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
    // 版本號是發布時間(年月日時分秒),字串比較就是時間比較。
    return saved.version.compareTo(bundled.version) >= 0 ? saved : bundled;
  }

  Future<Catalog> load() async => Catalog.fromEnvelopes(await current('food_list'), await current('units'));

  /// 每日檢查拿到新資料時呼叫。只存 App 支援的格式。
  Future<bool> apply(DatasetEnvelope env) async {
    if (!(supportedDatasetFormats[env.name] ?? const []).contains(env.formatVersion)) return false;
    await store.putDataset(env);
    return true;
  }
}
