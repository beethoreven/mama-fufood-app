import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log.dart';
import '../data/store.dart';
import '../services/daily_check.dart';
import '../state/providers.dart';
import 'first_run/principles_page.dart';
import 'flows.dart';
import 'more/babies_page.dart';
import 'more/feedback_page.dart';
import 'shell.dart';
import 'theme.dart';
import 'widgets/common.dart';
import '../services/feedback_service.dart';

/// 決定現在要顯示什麼:資料運用原則 → 第一個寶寶 → 強制更新 → 主畫面(SPEC 第 3、5 節)。
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> with WidgetsBindingObserver {
  String? _policyVersion;
  bool _askingBaby = false;
  bool _startedForeground = false;
  bool _noticeShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    rootBundle.loadString('assets/texts/policy_version.txt').then((v) {
      if (mounted) setState(() => _policyVersion = v.trim());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppLog.info('app.resumed');
      unawaited(ref.read(servicesProvider).onForeground());
    }
  }

  Future<void> _startOnce() async {
    if (_startedForeground) return;
    _startedForeground = true;
    final services = ref.read(servicesProvider);
    installConflictResolver(services, widget.navigatorKey, ref);
    await services.auth.init();
    unawaited(services.onForeground());
    // App 異常關閉後,下次開啟時提示(一天最多一次;只提示,不自動送)。
    final exit = await services.diagnostics.unexpectedExit();
    if (exit == null || !mounted) return;
    final ctx = widget.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final go = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        content: const Text('App 上次意外關閉，要送出意見回饋告訴我們嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('不要')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('要')),
        ],
      ),
    );
    if (!mounted) return;
    if (go == true) {
      final shell = ref.read(shellProvider.notifier);
      while (shell.pop()) {}
      shell.push(SubPage('意見回饋', (_) => const FeedbackPage(kind: FeedbackKind.problem)));
    } else {
      final c2 = widget.navigatorKey.currentContext;
      if (c2 != null && c2.mounted) {
        await showDialog(
          context: c2,
          builder: (c) => AlertDialog(
            content: const Text('如果問題持續發生，可點選右上角選單中的「意見回饋」提交問題，我們會嘗試進行修正。'),
            actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('好'))],
          ),
        );
      }
    }
  }

  Future<void> _askFirstBaby() async {
    if (_askingBaby) return;
    _askingBaby = true;
    final store = ref.read(storeProvider);
    while (mounted && (await store.babies()).isEmpty) {
      if (!mounted) break;
      final ctx = widget.navigatorKey.currentContext ?? context;
      if (!ctx.mounted) break;
      final name = await askBabyName(ctx,
          title: '第一個寶寶',
          dismissible: false,
          help: '請輸入你要記錄的第一個寶寶名稱，本名或乳名等等都可以，這個名字只有你自己會看到喔。');
      if (name == null) continue;
      try {
        final baby = await store.addBaby(name);
        await store.setSetting(Keys.currentBaby, '${baby.seq}');
        AppLog.info('baby.first_added');
      } on InputProblem catch (e) {
        if (ctx.mounted) toast(ctx, e.message);
      }
    }
    _askingBaby = false;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final babiesAsync = ref.watch(babiesProvider);
    final services = ref.watch(servicesProvider);
    final c = context.colors;
    if (!settingsAsync.hasValue || !babiesAsync.hasValue || _policyVersion == null) {
      return Scaffold(backgroundColor: c.bg, body: const SizedBox.expand());
    }
    final settings = settingsAsync.value!;
    final babies = babiesAsync.value!;
    AppLog.babyNames = [for (final b in babies) b.name];

    // 1. 資料運用原則(第一次開啟,或條款、政策改版後)。
    if (settings.policyAck != _policyVersion) {
      return PrinciplesPage(
        isUpdate: settings.policyAck != null,
        onAccepted: () => ref.read(storeProvider).setSetting(Keys.policyAck, _policyVersion),
      );
    }
    // 2. 沒有任何寶寶:跳出關不掉的輸入介面。
    if (babies.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askFirstBaby());
      return Scaffold(backgroundColor: c.bg, body: const SizedBox.expand());
    }
    // 3. 強制更新(只對有網路且有做版本檢查的手機生效)。
    final min = settings.raw[CheckKeys.forceMin];
    if (min != null && DailyCheckService.compareVersions(services.appVersion, min) < 0) {
      return _ForceUpdatePage(reason: settings.raw[CheckKeys.forceReason] ?? '', url: settings.raw[CheckKeys.forceUrl] ?? '');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startOnce());
      _maybeNotice(settings.raw[CheckKeys.notice]);
    });
    return const MainShell();
  }

  /// 「App 有重大更新,更新後才能抓新的清單」:不強制,關得掉(一直跳出來又關不掉的提示會讓 App 很難用)。
  void _maybeNotice(String? notice) {
    if (notice == null || notice.isEmpty || _noticeShown) return;
    _noticeShown = true;
    final ctx = widget.navigatorKey.currentContext;
    if (ctx != null) toast(ctx, notice);
  }
}

class _ForceUpdatePage extends StatelessWidget {
  const _ForceUpdatePage({required this.reason, required this.url});

  final String reason;
  final String url;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('需要更新', style: t.titleLarge),
              const SizedBox(height: 12),
              Text('這個版本需要更新才能繼續使用。', style: t.bodyLarge),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('原因：$reason', style: t.bodyLarge),
              ],
              const SizedBox(height: 16),
              Text(url.isEmpty ? '請向提供 App 的人取得新版本。' : '新版本：$url', style: t.bodyMedium),
            ]),
          ),
        ),
      ),
    );
  }
}
