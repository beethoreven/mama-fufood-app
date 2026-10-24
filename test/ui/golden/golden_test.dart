import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';
import '../scenarios.dart';

/// 截圖比對:每個主要畫面在 S21(預設字級)與小螢幕(大一級字)各一張,
/// 和 goldens/ 裡的截圖比,版面變了就失敗。文字畫成方塊,原因見 test/flutter_test_config.dart。
///
/// 故意改了版面時:`flutter test test/ui/golden --update-goldens` 重新產生,看過截圖再提交。
void main() {
  setUpUiTests();

  const combos = [(1, 1.0), (0, 1.15)];
  for (final s in scenarios) {
    final list = s.screens == null ? [for (final (i, scale) in combos) (screens[i], scale)] : [for (final x in s.screens!) (x, 1.0)];
    for (final (screen, scale) in list) {
      final id = '${s.name}_${screen.name}_${(scale * 100).round()}';
      testWidgets(id, (tester) async {
        // 方塊字的英數字比真字寬,這裡的「爆版」不準,交給 test/ui/layout/ 用真字型檢查;其他錯誤照樣算失敗。
        await runScenario(tester, s, screen, scale, ignoreOverflow: true, check: () async {
          await expectLater(find.byKey(shotKey), matchesGoldenFile('goldens/$id.png'));
        });
      });
    }
  }
}
