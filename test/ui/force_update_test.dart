import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/services/daily_check.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'harness.dart';
import 'scenarios.dart';

/// 被強制更新擋住時:一定能匯出(不放匯入),「前往更新」只打開 App 自己的 Release 或網站。
void main() {
  setUpUiTests();

  Future<void> blocked(WidgetTester tester, String url, Future<void> Function(_FakeLauncher launcher) check) async {
    final launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
    final s = Scenario('force_update', shows: () => find.text('需要更新'));
    await runScenario(tester, s, screens[1], 1.0, seed: (services) async {
      await services.store.setSetting(CheckKeys.forceMin, '9.0.0'); // 測試的 App 版本是 1.0.0
      await services.store.setSetting(CheckKeys.forceUrl, url);
      await services.store.setSetting(CheckKeys.forceAt, '${fixedNow.millisecondsSinceEpoch}');
    }, check: () => check(launcher));
  }

  testWidgets('伺服器 7 天都沒再確認「要更新」：不再擋，直接進主畫面', (tester) async {
    final s = Scenario('force_update_expired', shows: () => find.byTooltip('更多'));
    // 版面由畫面測試(test/ui/layout)負責;這裡只看有沒有被擋住,和其他走到主畫面的測試一樣不看溢出。
    await runScenario(tester, s, screens[1], 1.0, ignoreOverflow: true, seed: (services) async {
      await services.store.setSetting(CheckKeys.forceMin, '9.0.0');
      final confirmed = fixedNow.subtract(const Duration(days: 7));
      await services.store.setSetting(CheckKeys.forceAt, '${confirmed.millisecondsSinceEpoch}');
    }, check: () async {
      expect(find.text('需要更新'), findsNothing);
    });
  });

  testWidgets('不是我們的更新網址：不打開它，改開網站', (tester) async {
    await blocked(tester, 'https://example.com/mama-fufood.apk', (launcher) async {
      expect(find.textContaining('example.com'), findsNothing);
      await tap(tester, find.text('前往更新'));
      expect(launcher.opened, [UpdateLinks.website]);
      expect(find.textContaining('更新網址不對'), findsOneWidget);
    });
  });

  testWidgets('我們的 Release 網址照常打開', (tester) async {
    const release = 'https://github.com/beethoreven/mama-fufood-app/releases/latest';
    await blocked(tester, release, (launcher) async {
      await tap(tester, find.text('前往更新'));
      expect(launcher.opened, [release]);
    });
  });

  testWidgets('被擋住時還能匯出，但不能匯入', (tester) async {
    await blocked(tester, '', (launcher) async {
      await tap(tester, find.text('匯出紀錄'));
      expect(find.text('匯出'), findsWidgets);
      expect(find.text('匯入'), findsNothing);
    });
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
