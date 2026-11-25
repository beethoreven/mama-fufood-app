import 'package:flutter/foundation.dart';

import '../core/constants.dart';
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
  /// 伺服器最後一次確認「要強制更新」的時間(毫秒),見 DailyCheckService.blocks。
  static const forceAt = 'force_confirmed_at';
  static const notice = 'dataset_notice';
}

/// 強制更新畫面的「前往更新」能打開的網址。更新網址是後端給的;後端被入侵時,不能讓它把所有人
/// 帶去別人的下載頁,所以只打開 App 自己的 GitHub Release 或網站,其他網址(或沒給)一律改開網站。
abstract final class UpdateLinks {
  /// 網站,首頁有「下載最新版」。mama-fufood.github.io 根網域本身沒有網頁,網址要帶 repo 的路徑。
  static const website = 'https://mama-fufood.github.io/mama-fufood-web/';

  static bool allowed(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.hasPort || uri.userInfo.isNotEmpty) return false;
    if (uri.pathSegments.any((s) => s == '.' || s == '..')) return false;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    bool under(String prefix) => path == prefix || path.startsWith('$prefix/');
    if (host == 'mama-fufood.github.io') return under('/mama-fufood-web');
    // 只收 Release 的頁面與檔案:同一個 repo 的 issue 頁誰都能留言、附檔。
    if (host == 'github.com') return under('/beethoreven/mama-fufood-app/releases');
    return false;
  }

  /// 「前往更新」實際打開的網址。
  static String target(String url) => allowed(url) ? url.trim() : website;
}

class ForceUpdate {
  const ForceUpdate({required this.minVersion, required this.reason, required this.url});

  final String minVersion;
  final String reason;
  final String url;
}

/// 每日檢查:登入後,開 App 時每天自動檢查一次公用資料的版本與
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

  /// 現在要不要被強制更新擋住:目前的版本比後台設定的最低可用版本舊,而且伺服器最近
  /// [Timing.forceUpdateExpiry] 內還確認過。這段時間都沒有再確認(例如後端關掉、一直連不上)就不再擋;
  /// 之後檢查成功、伺服器還是說要更新,就會再擋。
  /// 沒有確認時間的旗標(加上這個期限之前存的)照樣擋,確認時間從下一次 [maybeRun] 起算。
  static bool blocks({required String appVersion, required String? minVersion, required String? confirmedAt}) {
    if (minVersion == null || compareVersions(appVersion, minVersion) >= 0) return false;
    final at = int.tryParse(confirmedAt ?? '');
    if (at == null) return true;
    return TimeRules.now().millisecondsSinceEpoch - at < Timing.forceUpdateExpiry.inMilliseconds;
  }

  /// 要擋就回傳強制更新的內容(畫面寫明原因),不用擋是 null。
  Future<ForceUpdate?> forceUpdate() async {
    final min = await store.getSetting(CheckKeys.forceMin);
    final at = await store.getSetting(CheckKeys.forceAt);
    if (min == null || !blocks(appVersion: appVersion(), minVersion: min, confirmedAt: at)) return null;
    return ForceUpdate(
      minVersion: min,
      reason: await store.getSetting(CheckKeys.forceReason) ?? '',
      url: await store.getSetting(CheckKeys.forceUrl) ?? '',
    );
  }

  /// 開 App 或回到前景時呼叫。
  Future<void> maybeRun() async {
    // 加上期限之前存的旗標沒有確認時間:從現在起算(沒登入也要算,不然永遠不會過期)。
    final min = await store.getSetting(CheckKeys.forceMin);
    if (min != null && await store.getSetting(CheckKeys.forceAt) == null) {
      await store.setSetting(CheckKeys.forceAt, '${TimeRules.now().millisecondsSinceEpoch}');
    } else if (min != null && compareVersions(appVersion(), min) < 0 && await forceUpdate() == null) {
      AppLog.info('force_update.expired');
    }
    // 登入已過期時不自動檢查(一定失敗,還會用掉重試次數);重新登入之後就會恢復。
    if (!api.configured || auth.state != AuthState.signedIn) return;
    final today = '${TimeRules.taipeiToday()}';
    // 正在被強制更新擋住時,每次開 App 都重新檢查(不受「一天一次」限制):後台可能已經調低門檻,
    // 不能讓使用者被擋到隔天。每天的次數上限照樣由後端管。
    final forced = await forceUpdate() != null;
    if (!forced && await store.getSetting(CheckKeys.lastOkDay) == today) return;
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
      var rejected = 0;
      final results = (res['datasets'] as Map? ?? const {}).cast<String, Object?>();
      String? notice;
      for (final e in results.entries) {
        final info = (e.value as Map).cast<String, Object?>();
        if (info['status'] == 'updated' && info['content'] is Map) {
          final version = info['version'], format = info['format_version'];
          final DatasetApply result;
          if (version is String && format is int) {
            result = await source.apply(DatasetEnvelope(
                name: e.key,
                version: version,
                formatVersion: format,
                content: (info['content'] as Map).cast<String, dynamic>()));
          } else {
            AppLog.warn('catalog.rejected', {'dataset': e.key, 'problem': 'envelope', 'n': 1});
            result = DatasetApply.rejected;
          }
          if (result == DatasetApply.applied) updated++;
          if (result == DatasetApply.rejected) rejected++;
        } else if (info['status'] == 'app_update_required') {
          notice = res['notice'] as String? ?? 'App 有重大更新，更新後才能抓新的清單。';
        }
      }
      await store.setSetting(CheckKeys.notice, notice);
      if (res['force_update'] == true) {
        await store.setSetting(CheckKeys.forceMin, res['min_app_version'] as String?);
        await store.setSetting(CheckKeys.forceReason, res['force_reason'] as String? ?? '');
        await store.setSetting(CheckKeys.forceUrl, res['update_url'] as String? ?? '');
        await store.setSetting(CheckKeys.forceAt, '${TimeRules.now().millisecondsSinceEpoch}');
      } else {
        await store.setSetting(CheckKeys.forceMin, null);
        await store.setSetting(CheckKeys.forceAt, null);
      }
      await store.setSetting(CheckKeys.lastOkDay, today);
      await store.setSetting(CheckKeys.lastAt, '${DateTime.now().millisecondsSinceEpoch}');
      await store.setSetting(CheckKeys.checksLeft, '${res['checks_left'] ?? ''}');
      // 後端順便換了一張新的通行證(舊的發出一段時間了)。
      final renewed = res['session_token'];
      final renewedExp = res['session_expires_at'];
      if (renewed is String && renewedExp is int) await auth.renewBackendToken(renewed, renewedExp);
      AppLog.info('check.ok', {'updated': updated, 'rejected': rejected, 'force': res['force_update'] == true});
      notifyListeners();
      if (notice != null) return notice;
      // 不合規則的內容沒有存。這次檢查還是算成功:同一天再試,拿到的也是同一份。
      if (rejected > 0) return '收到的公用資料有問題，先繼續用手機上的清單';
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
      return auth.signedIn ? '登入已過期，請重新登入 Google 帳號，才能更新公用資料' : '請先用 Google 帳號登入，才能更新公用資料';
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
