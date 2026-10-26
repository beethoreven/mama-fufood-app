import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/log.dart';
import '../../data/store.dart';
import '../../services/sync_engine.dart';
import '../../state/providers.dart';
import '../flows.dart';
import '../more/babies_page.dart';
import '../more/import_export_page.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 沒有任何寶寶時(第一次開啟、重裝、刪光寶寶之後)的畫面(SPEC 第 15 節):
/// 新增寶寶、從匯出檔匯入、從雲端取回,三選一。做完有寶寶了才進主畫面。
///
/// onBusy:匯入或取回進行中。進行中就算已經寫進寶寶,也先留在這一頁,
/// 讓流程(例如「匯入完成」的說明)走完再換畫面。
class FirstBabyPage extends ConsumerStatefulWidget {
  const FirstBabyPage({super.key, required this.navigatorKey, required this.onBusy});

  final GlobalKey<NavigatorState> navigatorKey;
  final ValueChanged<bool> onBusy;

  @override
  ConsumerState<FirstBabyPage> createState() => _FirstBabyPageState();
}

class _FirstBabyPageState extends ConsumerState<FirstBabyPage> {
  String? _step;
  bool _running = false;

  bool get _busy => _running || _step != null;

  void _setStep(String? s) {
    if (!mounted) return;
    setState(() => _step = s);
  }

  Future<void> _run(Future<void> Function() task) async {
    final services = ref.read(servicesProvider);
    setState(() => _running = true);
    widget.onBusy(true);
    try {
      // 這時主畫面還沒開過:先恢復登入狀態、接好衝突與整合問題的對話框。
      await services.auth.init();
      installConflictResolver(services, widget.navigatorKey, ref);
      await task();
    } finally {
      if (mounted) setState(() => _running = false);
      _setStep(null);
      widget.onBusy(false);
    }
  }

  Future<void> _add() async {
    final store = ref.read(storeProvider);
    final name = await askBabyName(context,
        title: '第一個寶寶', help: '本名或乳名等等都可以，這個名字只有你自己會看到喔。');
    if (name == null) return;
    try {
      final baby = await store.addBaby(name);
      await store.setSetting(Keys.currentBaby, '${baby.seq}');
      AppLog.info('baby.first_added');
    } on InputProblem catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _import() => _run(() => importFlow(context, ref, _setStep));

  Future<void> _restore() => _run(() async {
        final services = ref.read(servicesProvider);
        _setStep('從雲端取回資料，請勿關閉 App');
        await setRecordSync(context, services, true);
        final on = await services.store.getSetting(Keys.syncRecords) == '1';
        final babies = await services.store.babies();
        AppLog.info('first_run.restore', {'on': on, 'babies': babies.length, 'state': services.sync.state.name});
        if (!on || babies.isNotEmpty || !mounted) return;
        _setStep(null);
        final message = services.sync.state == SyncState.ok
            ? '雲端上沒有找到之前同步的寶寶。請新增寶寶，或改用匯出檔匯入。\n\n「紀錄與雲端同步」已經打開，之後新增的寶寶會同步到雲端。'
            : '這次沒有取回成功，請確認網路後再試一次。';
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(message),
            actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('好'))],
          ),
        );
      });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 32, 20, 20), children: [
            Icon(Symbols.child_care_rounded, size: 48, color: c.deco),
            const SizedBox(height: 12),
            Text('第一個寶寶', style: t.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('請新增你要記錄的第一個寶寶。', style: t.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: _busy ? null : _add, icon: const Icon(Icons.add_rounded), label: const Text('新增寶寶')),
            const SizedBox(height: 28),
            Text('之前用過這個 App 嗎？', style: t.titleSmall),
            const SizedBox(height: 8),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('有之前匯出的檔案（.mff），可以直接匯入。要用匯出時的 Google 帳號登入。', style: t.bodyMedium),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                    onPressed: _busy ? null : _import,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('從匯出檔匯入')),
              ]),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('之前有開「紀錄與雲端同步」的話，登入同一個 Google 帳號就能取回，並自動打開同步。', style: t.bodyMedium),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                    onPressed: _busy ? null : _restore,
                    icon: const Icon(Icons.cloud_download_rounded),
                    label: const Text('從雲端取回')),
              ]),
            ),
            if (_step != null) ...[
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Flexible(child: Text('$_step…', style: t.bodyMedium)),
              ]),
            ],
            const DisclaimerText(Disclaimers.general),
          ]),
        ),
      ),
    );
  }
}
