import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/core/constants.dart';
import 'package:mama_fufood/ui/record/record_dialog.dart';
import 'package:mama_fufood/ui/widgets/wheel_picker.dart';

import 'harness.dart';
import 'scenarios.dart';

/// 紀錄介面:選單開著時、以及選單關掉後 0.5 秒內,按「儲存」不動作;之後才會存。
void main() {
  setUpUiTests();

  testWidgets('選單關掉後 0.5 秒內按儲存不會存，之後才會', (tester) async {
    final s = Scenario('record_save_lock', go: (t) async {
      await openRecord(t);
      await tap(t, find.text('修改'));
    }, shows: () => find.text('修改紀錄'));
    // 這裡用測試內建的方塊字型,字比真的寬,版面溢出不算(版面另由 test/ui/layout 用真字型檢查)。
    await runScenario(tester, s, screens[1], 1.0, ignoreOverflow: true, check: () async {
      Future<void> frames(Duration d) async {
        for (var e = Duration.zero; e < d; e += const Duration(milliseconds: 50)) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      // 打開一個選單,點外面關掉,馬上按儲存:介面還在。
      await tester.tap(find.descendant(of: find.byType(RecordDialog), matching: find.byType(PickerButton)).first);
      await frames(const Duration(milliseconds: 400));
      await tester.tapAt(const Offset(4, 4));
      await frames(const Duration(milliseconds: 100));
      await tester.tap(find.text('儲存'));
      await frames(const Duration(milliseconds: 100));
      expect(find.text('修改紀錄'), findsOneWidget);

      // 解鎖之後再按:存好並關掉介面。
      await frames(Timing.saveUnlockAfterPicker);
      await tester.tap(find.text('儲存'));
      await settle(tester);
      expect(find.byType(RecordDialog), findsNothing);
    });
  });
}
