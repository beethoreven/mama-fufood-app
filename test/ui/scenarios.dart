import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/services/services.dart';
import 'package:mama_fufood/ui/record/record_dialog.dart';

import 'harness.dart';

/// 要檢查的畫面:從開 App 的畫面怎麼走過去、走到了要看得到什麼(版面檢查與截圖比對共用)。
class Scenario {
  const Scenario(this.name,
      {required this.shows, this.go, this.policyAccepted = true, this.theme = 'dark', this.screens, this.calendarVisible = false, this.noBabies = false});

  final String name;

  /// 確認真的到了這個畫面(不然畫面空白也會「通過」)。
  final Finder Function() shows;
  final Future<void> Function(WidgetTester tester)? go;
  final bool policyAccepted;
  final String theme;

  /// 只看部分尺寸(淺色主題只看一種,版面和深色一樣)。
  final List<Screen>? screens;

  /// 畫面上看得到月曆的格子(見 [minTapTarget])。
  final bool calendarVisible;

  /// 手機上沒有任何寶寶(第一次開啟、重裝之後)。
  final bool noBabies;
}

/// 觸控目標至少 48×48 dp(SPEC 第 1 節)。
/// 唯一的例外:月曆一列 7 格,螢幕不到 336 dp 寬時(例如 320 dp 的小螢幕每格只有 45.7 dp),
/// 寬度的標準放寬成「螢幕寬 ÷ 7」;格子的高度仍然要 48 dp 以上,其他元件也照樣要 48 dp。
Size minTapTarget(Scenario s, Screen screen) => Size(s.calendarVisible ? math.min(48, screen.width / 7) : 48, 48);

Future<void> openMenu(WidgetTester tester, String item) async {
  await tap(tester, find.byTooltip('更多'));
  await tap(tester, find.text(item).last);
}

Future<void> openDay(WidgetTester tester, int day) => tap(tester, find.text('$day').first);

Future<void> openRecord(WidgetTester tester, {String food = '菠菜'}) async {
  await openDay(tester, 23);
  await tap(tester, find.text(food).last);
}

const _note = '嘴巴周圍有點紅，半小時後消退。下次少一點再試。';

final scenarios = <Scenario>[
  Scenario('principles', policyAccepted: false, shows: () => find.text('資料運用原則')),
  Scenario('calendar', calendarVisible: true, shows: () => find.text('🍠地瓜')),
  // 6 列的月份(SPEC 第 11 節「月曆格子的實際尺寸驗證」):往前兩個月到 2026 年 8 月。
  Scenario('calendar_6weeks', calendarVisible: true, go: (t) async {
    await tap(t, find.byTooltip('上個月'));
    await tap(t, find.byTooltip('上個月'));
  }, shows: () => find.text('8 月')),
  Scenario('day_list', go: (t) => openDay(t, 23), shows: () => find.text('10 月 23 日')),
  Scenario('record_add', go: (t) => openDay(t, 27), shows: () => find.text('儲存')),
  Scenario('record_view', go: openRecord, shows: () => find.text(_note)),
  Scenario('record_edit', go: (t) async {
    await openRecord(t);
    await tap(t, find.text('修改'));
  }, shows: () => find.text('修改中')),
  // 地瓜有 3 筆紀錄,食材旁邊會出現喜好與過敏的圖示(點了跳說明,觸控範圍 48 dp)。
  Scenario('record_view_icons',
      go: (t) => openRecord(t, food: '地瓜'),
      shows: () => find.descendant(
            of: find.byType(RecordDialog),
            matching: find.bySemanticsLabel(RegExp(r'^（用食反應（排斥|接受|喜歡）|過敏狀況（穩定|風險|過敏））$')),
          )),
  Scenario('first_baby', noBabies: true, shows: () => find.text('從雲端取回')),
  Scenario('stats', go: (t) => tap(t, find.text('統計')), shows: () => find.textContaining('根莖')),
  Scenario('judgement', go: (t) => tap(t, find.text('食材判斷')), shows: () => find.text('喜好')),
  // 地瓜三筆(正常、腹瀉＋嘔吐、正常)兩個都算正常;南瓜兩筆都腹瀉,顯示腹瀉、嘔吐不顯示。
  Scenario('digestive', go: (t) => tap(t, find.text('腹瀉嘔吐')), shows: () => find.text('嘔吐')),
  Scenario('settings', go: (t) => openMenu(t, 'App 設定'), shows: () => find.text('週起始日')),
  Scenario('babies', go: (t) => openMenu(t, '寶寶們設定'), shows: () => find.text('二寶')),
  Scenario('import_export', go: (t) => openMenu(t, '匯入/匯出'), shows: () => find.text('匯出')),
  Scenario('guide',
      go: (t) => openMenu(t, '判斷邏輯說明'), shows: () => find.textContaining('這一頁在說什麼', findRichText: true)),
  Scenario('feedback', go: (t) => openMenu(t, '意見回饋'), shows: () => find.text('類型')),
  Scenario('calendar_light', theme: 'light', screens: [screens[1]], calendarVisible: true, shows: () => find.text('🍠地瓜')),
  Scenario('record_view_light', theme: 'light', screens: [screens[1]], go: openRecord, shows: () => find.text(_note)),
];

/// 開 App、走到這個畫面、確認真的到了,再做 [check]。不論成敗,最後都拆掉畫面與資料庫
/// (失敗時沒拆,下一個測試會跟著壞)。
Future<void> runScenario(
  WidgetTester tester,
  Scenario s,
  Screen screen,
  double scale, {
  double dpr = 1,
  bool ignoreOverflow = false,
  Future<void> Function(Services services)? seed,
  required Future<void> Function() check,
}) async {
  final services = (await tester.runAsync<Services>(() async {
    final services = await seededServices(policyAccepted: s.policyAccepted, theme: s.theme);
    if (s.noBabies) await services.store.db.delete(services.store.db.babies).go();
    await seed?.call(services);
    return services;
  }))!;
  final errors = ErrorLog.start();
  Object? failure;
  StackTrace? stack;
  try {
    await pumpApp(tester, services, screen, scale, dpr: dpr);
    await s.go?.call(tester);
  } catch (e, st) {
    failure = e;
    stack = st;
  } finally {
    errors.stop();
  }
  try {
    final relevant = errors.details.where((d) => !(ignoreOverflow && ErrorLog.isOverflow(d))).toList();
    expect(relevant, isEmpty, reason: errors.describe(relevant));
    if (failure != null) Error.throwWithStackTrace(failure, stack!);
    expect(s.shows(), findsWidgets, reason: '沒有走到「${s.name}」的畫面');
    await check();
  } finally {
    await tearDownApp(tester, services);
  }
}
