import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';
import 'scenarios.dart';

/// 換月:拖的時候這個月跟著手指走、旁邊的月份同時露出來。放手時甩得夠快(而且移動超過一小段)就依甩的方向換月;
/// 慢慢拖則要超過一半才換,不到一半滑回去。
void main() {
  setUpUiTests();

  testWidgets('拖曳時兩個月份一起移動，超過一半才換月', (tester) async {
    final s = Scenario('calendar_swipe', shows: () => find.text('10 月'));
    await runScenario(tester, s, screens[1], 1.0, ignoreOverflow: true, check: () async {
      final width = screens[1].width;
      final grid = tester.getCenter(find.text('15').first);

      // 慢慢拖 30%:十月和十一月都在畫面上(各有一個 15 號),還沒換月。
      final gesture = await slowDrag(tester, grid, -width * 0.3);
      expect(find.text('15'), findsNWidgets(2));
      await gesture.up();
      await settle(tester);
      expect(find.text('10 月'), findsOneWidget, reason: '不到一半,滑回原位');
      expect(find.text('15'), findsOneWidget);

      // 慢慢拖 60%:放手後換成十一月。
      await (await slowDrag(tester, grid, -width * 0.6)).up();
      await settle(tester);
      expect(find.text('11 月'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);

      // 按「上個月」也一樣是滑動換月。
      await tap(tester, find.byTooltip('上個月'));
      expect(find.text('10 月'), findsOneWidget);
    });
  });

  testWidgets('快速短撥會換月，方向跟著甩的方向', (tester) async {
    final s = Scenario('calendar_fling', shows: () => find.text('10 月'));
    await runScenario(tester, s, screens[1], 1.0, ignoreOverflow: true, check: () async {
      final grid = tester.getCenter(find.text('15').first);
      // 只移 60 邏輯像素(遠不到一半寬度),但速度每秒 1000:往左甩是下個月。
      await tester.flingFrom(grid, const Offset(-60, 0), 1000);
      await settle(tester);
      expect(find.text('11 月'), findsOneWidget);
      // 往右甩回上個月。
      await tester.flingFrom(tester.getCenter(find.text('15').first), const Offset(60, 0), 1000);
      await settle(tester);
      expect(find.text('10 月'), findsOneWidget);
    });
  });

  testWidgets('點日期時手滑一下(很快但只移 15 邏輯像素)不換月', (tester) async {
    final s = Scenario('calendar_slip', shows: () => find.text('10 月'));
    await runScenario(tester, s, screens[1], 1.0, ignoreOverflow: true, check: () async {
      await tester.flingFrom(tester.getCenter(find.text('15').first), const Offset(-15, 0), 1000);
      await settle(tester);
      // 移動太短,會被當成點那一天(打開當天的清單),但月曆還是十月。
      expect(find.text('11 月'), findsNothing);
      expect(find.text('10 月'), findsWidgets);
    });
  });
}

/// 慢慢拖 dx(每 100 毫秒移 dx 的十分之一,速度遠低於甩動門檻),拖完停一下再交給呼叫的人放手。
Future<TestGesture> slowDrag(WidgetTester tester, Offset from, double dx) async {
  var time = Duration.zero;
  final gesture = await tester.startGesture(from);
  for (var i = 0; i < 10; i++) {
    time += const Duration(milliseconds: 100);
    await gesture.moveBy(Offset(dx / 10, 0), timeStamp: time);
    await tester.pump(const Duration(milliseconds: 100));
  }
  return gesture;
}
