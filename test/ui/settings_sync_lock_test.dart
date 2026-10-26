import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/services/services.dart';
import 'package:mama_fufood/services/sync_engine.dart';

import 'harness.dart';
import 'scenarios.dart';

/// 同步正在跑的時候,雲端的兩個開關鎖住並顯示「正在同步」;離開設定頁再回來還是鎖住,同步完才解鎖。
void main() {
  setUpUiTests();

  testWidgets('同步中鎖住雲端開關，離開再回來還是鎖住', (tester) async {
    late Services services;
    final s = Scenario('settings_sync_lock', go: (t) => openMenu(t, 'App 設定'), shows: () => find.text('週起始日'));
    await runScenario(tester, s, screens[1], 1.0, ignoreOverflow: true, seed: (sv) async => services = sv, check: () async {
      Future<void> expectLocked(bool locked) async {
        final recordSwitch = find.widgetWithText(SwitchListTile, '紀錄與雲端同步');
        await tester.scrollUntilVisible(recordSwitch, 200, scrollable: find.byType(Scrollable).first);
        await settle(tester);
        for (final title in ['紀錄與雲端同步', '照片存到雲端']) {
          final tile = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title));
          expect(tile.onChanged == null, locked, reason: title);
        }
        expect(find.text('正在同步，請勿關閉 App'), locked ? findsOneWidget : findsNothing);
      }

      await expectLocked(false);
      services.sync.debugSetState(SyncState.syncing);
      await settle(tester);
      await expectLocked(true);

      // 離開設定頁(換到別的頁面,設定頁整個拆掉)再回來:同步還沒完,一樣鎖著。
      await openMenu(tester, '意見回饋');
      expect(find.text('週起始日'), findsNothing);
      await openMenu(tester, 'App 設定');
      await expectLocked(true);

      services.sync.debugSetState(SyncState.ok);
      await settle(tester);
      await expectLocked(false);
    });
  });
}
