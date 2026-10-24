import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/ui/more/text_pages.dart';
import 'package:mama_fufood/ui/theme.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  // 上一個測試留下的檔案快取綁著上一個測試的假時鐘,不清掉的話下一個測試讀檔會等不到。
  setUp(rootBundle.clear);

  testWidgets('從使用者條款切到隱私權政策，內容要跟著換', (tester) async {
    final asset = ValueNotifier('terms');
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: ValueListenableBuilder(valueListenable: asset, builder: (_, a, _) => LegalPage(asset: a))),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('本 App 是什麼', findRichText: true), findsOneWidget);

    asset.value = 'privacy';
    await tester.pumpAndSettle();
    expect(find.textContaining('一句話說明', findRichText: true), findsOneWidget);
    expect(find.textContaining('本 App 是什麼', findRichText: true), findsNothing);
  });

  testWidgets('條款裡的網址與 Email 點得下去', (tester) async {
    final launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: const Scaffold(body: LegalPage(asset: 'privacy')),
    ));
    await tester.pumpAndSettle();

    Future<void> tapText(String text) async {
      final finder = find.textContaining(text, findRichText: true).first;
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tapOnText(find.textRange.ofSubstring(text).first);
      await tester.pumpAndSettle();
    }

    // Email 本身只寫在條款裡,測試只點網域的部分。
    await tapText('outlook.com');
    await tapText('https://render.com/privacy');
    expect(launcher.opened, hasLength(2));
    expect(launcher.opened.first, allOf(startsWith('mailto:'), endsWith('@outlook.com')));
    expect(launcher.opened.last, 'https://render.com/privacy');
  });
}

class _FakeLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  final opened = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    return true;
  }
}
