import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mama_fufood/core/time.dart';
import 'package:mama_fufood/data/database.dart';
import 'package:mama_fufood/data/store.dart';
import 'package:mama_fufood/services/api_client.dart';
import 'package:mama_fufood/services/auth_service.dart';
import 'package:mama_fufood/services/daily_check.dart';
import 'package:mama_fufood/services/services.dart';

/// 被強制更新擋住時,不能「一天只檢查一次」:後台調低門檻後,下次開 App 就要能解除。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // 內建的公用資料從 assets 讀

  test('被強制更新擋住時，每次開 App 都重新檢查；後台調低門檻就解除', () async {
    final store = Store(AppDb(NativeDatabase.memory()));
    addTearDown(store.db.close);
    await store.setSetting('auth_user', jsonEncode({'sub': 'u1', 'email': 'mom@example.com'}));
    await store.setSetting('auth_app_token', 'mff1.x.y');
    await store.setSetting('auth_app_token_exp', '${DateTime.now().add(const Duration(days: 100)).millisecondsSinceEpoch ~/ 1000}');
    final auth = AuthService(StoreAuthStorage(store));
    await auth.init();

    var minVersion = '1.0.0';
    var calls = 0;
    final api = ApiClient(auth, baseUrl: 'https://backend.test', client: MockClient((req) async {
      calls++;
      return http.Response(
          jsonEncode({
            'min_app_version': minVersion,
            'force_update': DailyCheckService.compareVersions('0.1.0', minVersion) < 0,
            'force_reason': '',
            'update_url': '',
            'checks_left': 9,
            'datasets': {},
          }),
          200,
          headers: {'content-type': 'application/json'});
    }));
    final check = DailyCheckService(store: store, auth: auth, api: api, appVersion: () => '0.1.0');

    await check.maybeRun();
    expect(await check.forceUpdate(), isNotNull, reason: '門檻 1.0.0,0.1.0 被擋');
    expect(await store.getSetting(CheckKeys.lastOkDay), '${TimeRules.taipeiToday()}');

    // 後台把門檻改成 0.1.0。同一天再開 App:被擋住的狀態要重新檢查,而且解除。
    minVersion = '0.1.0';
    await check.maybeRun();
    expect(calls, 2);
    expect(await check.forceUpdate(), isNull);

    // 沒被擋住時,同一天不再重複檢查。
    await check.maybeRun();
    expect(calls, 2);
  });

  test('登入已過期時不自動檢查，也不記成失敗(重新登入後才不會被重試上限擋住)', () async {
    final store = Store(AppDb(NativeDatabase.memory()));
    addTearDown(store.db.close);
    await store.setSetting('auth_user', jsonEncode({'sub': 'u1', 'email': 'mom@example.com'}));
    await store.setSetting('auth_app_token', 'mff1.x.y');
    await store.setSetting('auth_app_token_exp', '${DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000}');
    final auth = AuthService(StoreAuthStorage(store));
    var calls = 0;
    final api = ApiClient(auth, baseUrl: 'https://backend.test', client: MockClient((req) async {
      calls++;
      return http.Response('{}', 500);
    }));
    auth.exchange = api.createSession;
    await auth.init();
    expect(auth.state, AuthState.sessionExpired);

    final check = DailyCheckService(store: store, auth: auth, api: api, appVersion: () => '0.1.0');
    await check.maybeRun();
    expect(calls, 0);
    expect(await store.getSetting(CheckKeys.failCount), isNull);

    // 手動檢查:告訴使用者要重新登入,同樣不記成失敗。
    expect(await check.run(), contains('登入已過期'));
    expect(calls, 0);
    expect(await store.getSetting(CheckKeys.failCount), isNull);
  });

  test('收到不合規則的公用資料：不存，照實告訴使用者，這次檢查仍算成功（同一天不再重試）', () async {
    final store = Store(AppDb(NativeDatabase.memory()));
    addTearDown(store.db.close);
    await store.setSetting('auth_user', jsonEncode({'sub': 'u1', 'email': 'mom@example.com'}));
    await store.setSetting('auth_app_token', 'mff1.x.y');
    await store.setSetting('auth_app_token_exp', '${DateTime.now().add(const Duration(days: 100)).millisecondsSinceEpoch ~/ 1000}');
    final auth = AuthService(StoreAuthStorage(store));
    await auth.init();

    // 少了一種食材(ID 永遠不可刪);單位的版本不是文字。
    final foods = (jsonDecode(File('assets/datasets/food_list.json').readAsStringSync()) as Map)['content'] as Map;
    (foods['foods'] as List).removeLast();
    final units = (jsonDecode(File('assets/datasets/units.json').readAsStringSync()) as Map)['content'];
    final api = ApiClient(auth, baseUrl: 'https://backend.test', client: MockClient((req) async {
      return http.Response(
          jsonEncode({
            'min_app_version': '0.1.0',
            'force_update': false,
            'force_reason': '',
            'update_url': '',
            'checks_left': 9,
            'datasets': {
              'food_list': {'status': 'updated', 'version': '20991231000000', 'format_version': 1, 'content': foods},
              'units': {'status': 'updated', 'version': 20991231000000, 'format_version': 1, 'content': units},
            },
          }),
          200,
          headers: {'content-type': 'application/json'});
    }));
    final check = DailyCheckService(store: store, auth: auth, api: api, appVersion: () => '0.1.0');

    expect(await check.run(), '收到的公用資料有問題，先繼續用手機上的清單');
    expect(await store.getDataset('food_list'), isNull);
    expect(await store.getDataset('units'), isNull);
    expect(await store.getSetting(CheckKeys.lastOkDay), '${TimeRules.taipeiToday()}');
  });
}
