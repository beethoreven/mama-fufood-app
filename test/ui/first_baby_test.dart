import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/ui/shell.dart';

import 'harness.dart';
import 'scenarios.dart';

/// 沒有寶寶時是「第一個寶寶」頁:三個選擇;新增寶寶之後進主畫面。
void main() {
  setUpUiTests();

  testWidgets('新增寶寶後進主畫面', (tester) async {
    final s = scenarios.firstWhere((x) => x.name == 'first_baby');
    // 方塊字型比真的字寬,版面溢出另由 test/ui/layout 用真字型檢查。
    await runScenario(tester, s, screens[1], 1.0, ignoreOverflow: true, check: () async {
      expect(find.text('新增寶寶'), findsOneWidget);
      expect(find.text('從匯出檔匯入'), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
      // 主畫面的頂部列用方塊字型會溢出(真字型不會,見 test/ui/layout),這裡只收其他錯誤。
      final errors = ErrorLog.start();
      try {
        await tap(tester, find.text('新增寶寶'));
        await tester.enterText(find.byType(TextField), '小明');
        await tester.tap(find.text('確定'));
        // 新增寶寶是資料庫交易:真的時間和畫面的時間交替跑,交易才走得完。
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await settle(tester);
        expect(find.byType(MainShell), findsOneWidget);
        expect(find.textContaining('小明的副食品記錄'), findsOneWidget);
      } finally {
        errors.stop();
      }
      expect(errors.details.where((d) => !ErrorLog.isOverflow(d)), isEmpty);
    });
  });
}
