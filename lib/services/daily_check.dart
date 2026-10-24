import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/env.dart';
import '../core/log.dart';
import '../core/time.dart';
import '../data/catalog_source.dart';
import '../data/store.dart';
import '../domain/catalog.dart';
import 'api_client.dart';
import 'auth_service.dart';

abstract final class CheckKeys {
  static const lastOkDay = 'check_last_ok_day';
  static const lastAt = 'check_last_at';
  static const failDay = 'check_fail_day';
  static const failCount = 'check_fail_count';
  static const failAt = 'check_fail_at';
  static const checksLeft = 'check_left';
  static const forceMin = 'force_min_version';
  static const forceReason = 'force_reason';
  static const forceUrl = 'force_url';
  static const notice = 'dataset_notice';
}

class ForceUpdate {
  const ForceUpdate({required this.minVersion, required this.reason, required this.url});

  final String minVersion;
  final String reason;
  final String url;
}

/// 每日檢查(SPEC 第 3 節第 2、3 項):登入後,開 App 時每天自動檢查一次公用資料的版本與
/// 最低可用 App 版本;失敗至少間隔 2 小時、一天最多重試 5 次;App 設定也可以手動檢查
/// (和自動檢查共用伺服器的每日 10 次)。「一天」以台北時間計。
class DailyCheckService extends ChangeNotifier {
  DailyCheckService({required this.store, required this.auth, required this.api, required this.appVersion});

  final Store store;
  final AuthService auth;
  final ApiClient api;
  final String Function() appVersion;
  bool _running = false;

  static int compareVersions(String a, String b) {
    List<int> parts(String v) => v.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    final x = parts(a), y = parts(b);
    for (var i = 0; i < 3; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }

  /// 目前的版本比後台設定的最低可用版本舊 → 強制更新(畫面寫明原因)。
  Future<ForceUpdate?> forceUpdate() async {
    final min = await store.getSetting(CheckKeys.forceMin);
    if (min == null || compareVersions(appVersion(), min) >= 0) return null;
    return ForceUpdate(
      minVersion: min,
      reason: await store.getSetting(CheckKeys.forceReason) ?? '',
      url: await store.getSetting(CheckKeys.forceUrl) ?? '',
    );
  }

  /// 開 App 或回到前景時呼叫。
  Future<void> maybeRun() async {
    if (!Env.backendConfigured || !auth.signedIn) return;
    final today = '${TimeRules.taipeiToday()}';
    if (await store.getSetting(CheckKeys.lastOkDay) == today) return;
    if (await store.getSetting(CheckKeys.failDay) == today) {
      final count = int.tryParse(await store.getSetting(CheckKeys.failCount) ?? '') ?? 0;
      final at = int.tryParse(await store.getSetting(CheckKeys.failAt) ?? '') ?? 0;
      if (count >= Timing.dailyCheckRetriesPerDay) return;
      if (DateTime.now().millisecondsSinceEpoch - at < Timing.dailyCheckRetryGap.inMilliseconds) return;
    }
    try {
      await run();
    } catch (_) {
      // 已經記下失敗;下次開 App 再試。
    }
  }

  /// 執行一次檢查。手動檢查也走這裡。回傳給使用者看的結果。
  Future<String> run() async {
    if (_running) return '正在檢查中';
    _running = true;
    final source = CatalogSource(store);
    final today = '${TimeRules.taipeiToday()}';
    try {
      final datasets = <String, Map<String, Object?>>{};
      for (final name in supportedDatasetFormats.keys) {
        final current = await source.current(name);
        datasets[name] = {'version': current.version, 'formats': supportedDatasetFormats[name]};
      }
      final res = await api.check(appVersion: appVersion(), datasets: datasets);
      var updated = 0;
      final results = (res['datasets'] as Map? ?? const {}).cast<String, Object?>();
      String? notice;
      for (final e in results.entries) {
        final info = (e.value as Map).cast<String, Object?>();
        if (info['status'] == 'updated' && info['content'] is Map) {
          final applied = await source.apply(DatasetEnvelope(
            name: e.key,
            version: info['version'] as String,
            formatVersion: info['format_version'] as int,
            content: (info['content'] as Map).cast<String, dynamic>(),
          ));
          if (applied) updated++;
        } else if (info['status'] == 'app_update_required') {
          notice = res['notice'] as String? ?? 'App 有重大更新，更新後才能抓新的清單。';
        }
      }
      await store.setSetting(CheckKeys.notice, notice);
      if (res['force_update'] == true) {
        await store.setSetting(CheckKeys.forceMin, res['min_app_version'] as String?);
        await store.setSetting(CheckKeys.forceReason, res['force_reason'] as String? ?? '');
        await store.setSetting(CheckKeys.forceUrl, res['update_url'] as String? ?? '');
      } else {
        await store.setSetting(CheckKeys.forceMin, null);
      }
      await store.setSetting(CheckKeys.lastOkDay, today);
      await store.setSetting(CheckKeys.lastAt, '${DateTime.now().millisecondsSinceEpoch}');
      await store.setSetting(CheckKeys.checksLeft, '${res['checks_left'] ?? ''}');
      AppLog.info('check.ok', {'updated': updated, 'force': res['force_update'] == true});
      notifyListeners();
      if (notice != null) return notice;
      return updated > 0 ? '已更新公用資料' : '公用資料已是最新';
    } on ApiError catch (e) {
      AppLog.warn('check.failed', {'status': e.status, 'code': e.code});
      if (e.isDailyLimit) {
        // 今天的額度用完了:今天不再自動重試。
        await store.setSetting(CheckKeys.checksLeft, '0');
        await store.setSetting(CheckKeys.failDay, today);
        await store.setSetting(CheckKeys.failCount, '${Timing.dailyCheckRetriesPerDay}');
        notifyListeners();
        return '今天的檢查次數已經用完，明天會自動恢復';
      }
      await _noteFailure(today);
      return e.isNotReady ? '暫時無法檢查，請稍後再試' : e.message;
    } on NotSignedIn {
      return '請先用 Google 帳號登入，才能更新公用資料';
    } catch (e, st) {
      AppLog.error('check.error', e, st);
      await _noteFailure(today);
      return '檢查失敗，請稍後再試';
    } finally {
      _running = false;
    }
  }

  Future<void> _noteFailure(String today) async {
    final sameDay = await store.getSetting(CheckKeys.failDay) == today;
    final count = sameDay ? (int.tryParse(await store.getSetting(CheckKeys.failCount) ?? '') ?? 0) : 0;
    await store.setSetting(CheckKeys.failDay, today);
    await store.setSetting(CheckKeys.failCount, '${count + 1}');
    await store.setSetting(CheckKeys.failAt, '${DateTime.now().millisecondsSinceEpoch}');
  }
}
