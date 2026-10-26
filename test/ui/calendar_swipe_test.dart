import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';
import 'scenarios.dart';

/// 換月:拖的時候這個月跟著手指走、旁邊的月份同時露出來;放手不到一半就滑回去,超過一半就換月。
void main() {
  setUpUiTests();

  testWidgets('拖曳時兩個月份一起移動，超過一半才換月', (tester) async {
    final s = Scenario('calendar_swipe', shows: () => find.text('10 月'));
    await runScenario(tester, s, screens[1], 1.0, ignoreOverflow: true, check: () async {
      final width = screens[1].width;
      final grid = tester.getCenter(find.text('15').first);

      // 拖 30%:十月和十一月都在畫面上(各有一個 15 號),還沒換月。
      final gesture = await tester.startGesture(grid);
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(Offset(-width * 0.05, 0));
        await tester.pump();
      }
      expect(find.text('15'), findsNWidgets(2));
      await gesture.up();
      await settle(tester);
      expect(find.text('10 月'), findsOneWidget, reason: '不到一半,滑回原位');
      expect(find.text('15'), findsOneWidget);

      // 拖 60%:放手後換成十一月。
      await tester.dragFrom(grid, Offset(-width * 0.6, 0));
      await settle(tester);
      expect(find.text('11 月'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);

      // 按「上個月」也一樣是滑動換月。
      await tap(tester, find.byTooltip('上個月'));
      expect(find.text('10 月'), findsOneWidget);
    });
  });
}
