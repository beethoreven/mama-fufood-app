import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/app.dart';
import 'package:mama_fufood/core/text.dart';
import 'package:mama_fufood/core/time.dart';
import 'package:mama_fufood/data/database.dart';
import 'package:mama_fufood/data/store.dart';
import 'package:mama_fufood/domain/record.dart';
import 'package:mama_fufood/services/diagnostics.dart';
import 'package:mama_fufood/services/services.dart';
import 'package:mama_fufood/state/providers.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 驗證的螢幕尺寸(SPEC 第 1 節):小螢幕約 320×640、S21、大螢幕約 412×915(單位 dp)。
/// 上下的系統列:小螢幕假設是舊手機的三個按鈕導覽列(48 dp),其他是手勢導覽列。
class Screen {
  const Screen(this.name, this.width, this.height, {required this.top, required this.bottom});

  final String name;
  final double width;
  final double height;
  final double top;
  final double bottom;
}

const screens = [
  Screen('small', 320, 640, top: 24, bottom: 48),
  Screen('s21', 360, 800, top: 24, bottom: 24),
  Screen('large', 412, 915, top: 24, bottom: 24),
];

/// 系統字型:預設與略大一級(Android 的「大」是 1.15 倍),不測最大字級(SPEC 第 1 節)。
const textScales = [1.0, 1.15];

/// 測試裡的「現在」:2026-10-23(五)晚上 8 點(本機時間;紀錄都帶 +08:00,畫面和電腦的時區無關,
/// 2026-10-23 在台北、UTC、洛杉磯時區跑過都一樣)。
final fixedNow = DateTime(2026, 10, 23, 20, 0);

const _diagnosticsChannel = MethodChannel('tw.com.tutorarthur.mamafufood/diagnostics');

/// 每個測試檔的 main() 開頭呼叫一次。
void setUpUiTests() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tmp;
  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('mff_ui_');
    // App 自己的原生程式(DiagnosticsChannel.kt)在測試裡不存在,換成固定的回答。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _diagnosticsChannel,
      (call) async => switch (call.method) {
        'noBackupDir' => tmp.path,
        'exitReasons' => const <Object?>[],
        'device' || 'state' => const <String, Object?>{},
        'logcat' => '',
        _ => null,
      },
    );
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));
  setUp(() {
    TimeRules.now = () => fixedNow;
    // rootBundle 會快取讀過的檔案,快取的結果綁在上一個測試的假時鐘上,
    // 不清掉的話,下一個測試讀政策版本、食材清單會永遠等不到(畫面一片空白)。
    rootBundle.clear();
  });
  tearDown(() => TimeRules.now = DateTime.now);
}

/// 一支「用了一陣子」的手機:看過資料運用原則、有兩個寶寶、小寶 8 月與 10 月有幾天的紀錄
/// (2026 年 8 月從星期六開始,週一起始時月曆有 6 列,是格子最擠的情況)。
/// 要在 tester.runAsync 裡呼叫(資料庫的讀寫是真的非同步)。
Future<Services> seededServices({bool policyAccepted = true, String theme = 'dark'}) async {
  final store = Store(AppDb(NativeDatabase.memory()));
  final diagnostics = Diagnostics(store);
  await diagnostics.init();
  final services = Services.forTest(
    store: store,
    diagnostics: diagnostics,
    package: PackageInfo(appName: '媽媽記副食品', packageName: 'tw.com.tutorarthur.mamafufood', version: '1.0.0', buildNumber: '1000'),
  );
  if (policyAccepted) {
    await store.setSetting(Keys.policyAck, File('assets/texts/policy_version.txt').readAsStringSync().trim());
  }
  await store.setSetting(Keys.theme, theme);
  final baby = await store.addBaby('小寶');
  await store.addBaby('二寶');
  await store.setSetting(Keys.currentBaby, '${baby.seq}');
  Future<void> add(int day, int hour, int minute, int food, int prepared, int eaten,
      {int month = 10, Allergy? allergy = Allergy.none, Reaction? reaction = Reaction.like, String note = ''}) {
    return store.saveRecord(
      FeedRecord(
        id: newId(),
        babySeq: baby.seq,
        timeUtcMs: TimeRules.toUtcMs(Day(2026, month, day), hour, minute, TimeRules.taipeiOffsetMinutes),
        tzOffsetMinutes: TimeRules.taipeiOffsetMinutes,
        foodId: food,
        preparedCenti: prepared,
        preparedUnitId: 1,
        eatenCenti: eaten,
        eatenUnitId: 1,
        allergy: allergy,
        reaction: reaction,
        note: note,
        photoIds: const [],
        createdAtMs: 0,
        updatedAtMs: 0,
      ),
      isNew: true,
    );
  }

  // 食材 ID:1 十倍粥、2 糙米粥、7 吐司、8 地瓜、9 馬鈴薯、10 胡蘿蔔、17 高麗菜、20 菠菜、32 南瓜、33 小黃瓜
  // (assets/datasets/food_list.json)。
  await add(1, 9, 0, 2, 3000, 2500, month: 8);
  await add(15, 9, 0, 9, 2000, 1500, month: 8);
  await add(15, 12, 0, 17, 1500, 1000, month: 8);
  await add(15, 18, 0, 33, 1500, 1500, month: 8);
  await add(31, 8, 0, 7, 1000, 800, month: 8);
  await add(31, 11, 0, 9, 2000, 2000, month: 8);
  await add(31, 15, 0, 17, 1500, 500, month: 8, reaction: Reaction.reject);
  await add(31, 18, 0, 2, 3000, 3000, month: 8);
  await add(2, 9, 0, 1, 3000, 2550);
  await add(2, 17, 30, 8, 2000, 1500, reaction: Reaction.accept);
  await add(9, 10, 0, 10, 2000, 1800);
  await add(16, 9, 0, 1, 3000, 3000);
  await add(16, 12, 0, 32, 2500, 1000, allergy: Allergy.nextDay, reaction: Reaction.reject);
  await add(16, 18, 0, 8, 2000, 2000);
  await add(23, 8, 0, 8, 3000, 2550);
  await add(23, 11, 0, 20, 1500, 500,
      allergy: Allergy.sameDay, reaction: Reaction.reject, note: '嘴巴周圍有點紅，半小時後消退。下次少一點再試。');
  await add(23, 15, 0, 32, 2000, 1200, reaction: Reaction.accept);
  await add(23, 18, 30, 1, 3000, 2800);
  return services;
}

final shotKey = GlobalKey(debugLabel: 'screenshot');

/// 設定螢幕尺寸、系統列與字級,開啟 App。dpr 只影響截圖的解析度,不影響版面。
Future<void> pumpApp(WidgetTester tester, Services services, Screen screen, double textScale, {double dpr = 1}) async {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(screen.width * dpr, screen.height * dpr);
  final insets = FakeViewPadding(top: screen.top * dpr, bottom: screen.bottom * dpr);
  tester.view.padding = insets;
  tester.view.viewPadding = insets;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(ProviderScope(
    overrides: [servicesProvider.overrideWithValue(services)],
    child: RepaintBoundary(key: shotKey, child: const MamaApp()),
  ));
  await settle(tester);
}

/// 等畫面穩定。不用 pumpAndSettle:有轉圈圈的畫面永遠不會「settle」。
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// 收集畫面的錯誤(例如版面爆掉)。失敗訊息裡會有是哪個元件、在哪個檔案第幾行。
/// 測試結束前一定要 stop()(Flutter 會檢查 FlutterError.onError 有沒有還原)。
class ErrorLog {
  ErrorLog.start() : _previous = FlutterError.onError {
    FlutterError.onError = details.add;
  }

  final FlutterExceptionHandler? _previous;
  final details = <FlutterErrorDetails>[];

  void stop() => FlutterError.onError = _previous;

  static bool isOverflow(FlutterErrorDetails d) => d.exceptionAsString().contains('overflowed');

  String describe(Iterable<FlutterErrorDetails> list) => list.map((d) => d.toString()).join('\n\n');
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await settle(tester);
}

/// 測試結束前拆掉畫面、關掉資料庫(不然資料庫的串流會留下還沒跑完的計時器)。
Future<void> tearDownApp(WidgetTester tester, Services services) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // 存過紀錄的畫面會排一個 8 秒後的同步;不取消的話測試結束時會報「還有計時器沒跑完」。
  services.sync.dispose();
  await settle(tester);
  await tester.runAsync(() => services.store.db.close());
}
