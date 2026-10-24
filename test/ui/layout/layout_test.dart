import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';
import '../scenarios.dart';

/// 版面檢查(SPEC 第 1 節「版面相容」):每個主要畫面 × 三種螢幕 × 兩種字級,用 App 的真字型。
/// 1. 版面不能爆掉(文字或元件超出範圍時,Flutter 會報 overflow);
/// 2. 觸控目標至少 48 dp(Android 的無障礙規範,也是 SPEC 的規定)。
///
/// 想看實際的樣子:`flutter test test/ui/layout --dart-define=MFF_SHOTS=true --update-goldens`,
/// 截圖存到 test/ui/layout/shots/(不進 git)。
const _shots = bool.fromEnvironment('MFF_SHOTS');

void main() {
  setUpUiTests();

  for (final s in scenarios) {
    for (final screen in s.screens ?? screens) {
      for (final scale in textScales) {
        final id = '${s.name}_${screen.name}_${(scale * 100).round()}';
        testWidgets(id, (tester) async {
          await runScenario(tester, s, screen, scale, dpr: _shots ? 2 : 1, check: () async {
            await expectLater(
              tester,
              meetsGuideline(MinimumTapTargetGuideline(
                size: minTapTarget(s, screen),
                link: 'https://support.google.com/accessibility/android/answer/7101858',
              )),
            );
            if (_shots) await expectLater(find.byKey(shotKey), matchesGoldenFile('shots/$id.png'));
          });
        });
      }
    }
  }
}
