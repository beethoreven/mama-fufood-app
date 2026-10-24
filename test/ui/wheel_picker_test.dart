import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/core/constants.dart';
import 'package:mama_fufood/ui/theme.dart';
import 'package:mama_fufood/ui/widgets/wheel_picker.dart';

void main() {
  /// 打開選單,回傳一個會記下選了什麼的盒子(不直接 await,選單沒關的話測試會卡住)。
  Future<List<String?>> openPicker(WidgetTester tester, {String? initial, Duration? idle}) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      builder: idle == null
          ? null
          : (context, child) => PickerTiming(autoApply: Timing.pickerAutoApply, idleApply: idle, child: child!),
      home: const Scaffold(),
    ));
    final picked = <String?>[];
    showWheelPicker<String>(tester.element(find.byType(Scaffold)),
            items: const ['甲', '乙', '丙'], initial: initial, label: (s) => s)
        .then(picked.add);
    await tester.pump();
    return picked;
  }

  Future<void> wait(WidgetTester tester, Duration d) async {
    for (var e = Duration.zero; e < d; e += const Duration(milliseconds: 50)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('打開後完全沒動，1.5 秒後選定目前停的那一項', (tester) async {
    final picked = await openPicker(tester);
    await wait(tester, Timing.pickerIdleApply - const Duration(milliseconds: 200));
    expect(picked, isEmpty, reason: '1.5 秒前選單還開著');
    await wait(tester, const Duration(milliseconds: 600));
    expect(picked, ['甲']);
  });

  testWidgets('有原本的值時，沒動就選原本的值', (tester) async {
    final picked = await openPicker(tester, initial: '丙');
    await wait(tester, Timing.pickerIdleApply + const Duration(milliseconds: 400));
    expect(picked, ['丙']);
  });

  testWidgets('沒動多久選定可以改（App 設定）', (tester) async {
    final picked = await openPicker(tester, idle: const Duration(seconds: 3));
    await wait(tester, const Duration(milliseconds: 2800));
    expect(picked, isEmpty);
    expect(find.textContaining('沒動的話 3 秒後'), findsOneWidget);
    await wait(tester, const Duration(milliseconds: 400));
    expect(picked, ['甲']);
  });
}
