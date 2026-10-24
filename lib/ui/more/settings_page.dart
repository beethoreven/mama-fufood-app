import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../data/store.dart';
import '../../services/daily_check.dart';
import '../../services/platform.dart';
import '../../services/sync_engine.dart';
import '../../state/providers.dart';
import '../flows.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// App 設定(SPEC 第 6 節):週起始日、主題、紀錄同步開關、照片雲端開關(含固定提醒文字)、
/// 需登入才能更新公用資料的說明、App 版本與各資料集版本及最後檢查時間、手動「檢查更新」、
/// 開放原始碼授權。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _checking = false;
  bool _toggling = false;

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    final settings = settingsOf(ref);
    final raw = settings.raw;
    final user = ref.watch(authUserProvider);
    final catalog = ref.watch(catalogProvider).value;
    final c = context.colors;
    final store = services.store;
    final lastCheck = int.tryParse(raw[CheckKeys.lastAt] ?? '');
    final lastSync = int.tryParse(raw[SyncKeys.lastOk] ?? '');
    final syncError = raw[SyncKeys.lastError];
    String fmt(int? ms) {
      if (ms == null) return '還沒有';
      final t = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${t.year}/${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }

    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 6), child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
            AppCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: children)),
          ]),
        );

    final paused = user == null && (settings.syncRecords || settings.syncPhotos);
    return ListView(padding: const EdgeInsets.all(12), children: [
      section('顯示', [
        ListTile(
          title: const Text('週起始日'),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 'monday', label: Text('星期一')), ButtonSegment(value: 'sunday', label: Text('星期日'))],
              selected: {settings.weekStartsMonday ? 'monday' : 'sunday'},
              onSelectionChanged: (v) => store.setSetting(Keys.weekStart, v.first),
            ),
          ),
        ),
        ListTile(
          title: const Text('主題'),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'dark', label: Text('深色')),
                ButtonSegment(value: 'light', label: Text('淺色')),
                ButtonSegment(value: 'system', label: Text('跟隨系統')),
              ],
              selected: {settings.themeCode},
              onSelectionChanged: (v) => store.setSetting(Keys.theme, v.first),
            ),
          ),
        ),
      ]),
      section('雲端', [
        SwitchListTile(
          title: const Text('紀錄與雲端同步'),
          subtitle: Text(paused
              ? '已暫停(未登入)'
              : settings.syncRecords
                  ? '最後同步:${fmt(lastSync)}${syncError != null ? '(上次失敗,稍後自動重試)' : ''}'
                  : '存到你自己的 Google 雲端硬碟中只有本 App 能讀取的區域'),
          value: settings.syncRecords,
          onChanged: _toggling
              ? null
              : (v) async {
                  setState(() => _toggling = true);
                  try {
                    await setRecordSync(context, services, v);
                  } finally {
                    if (mounted) setState(() => _toggling = false);
                  }
                },
        ),
        SwitchListTile(
          title: const Text('照片存到雲端'),
          subtitle: Text(paused ? '已暫停(未登入)' : '存到你的雲端硬碟「媽媽記副食品/照片」資料夾,上傳成功後才刪掉手機上的照片'),
          value: settings.syncPhotos,
          onChanged: _toggling
              ? null
              : (v) async {
                  setState(() => _toggling = true);
                  try {
                    await setPhotoSync(context, services, v);
                  } finally {
                    if (mounted) setState(() => _toggling = false);
                  }
                },
        ),
        // 規格要求寫死的提醒(SPEC 第 4 節)。
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text('只開「照片存到雲端」、沒開「紀錄與雲端同步」時,手機遺失後照片會留在你的雲端硬碟,但對應的紀錄會遺失。',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: c.warn)),
        ),
        if (settings.syncRecords && user != null)
          ListTile(
            leading: const Icon(Icons.sync_rounded),
            title: const Text('現在同步'),
            onTap: () async {
              await services.sync.syncNow(reason: 'manual');
              if (!context.mounted) return;
              toast(context, services.sync.state == SyncState.ok ? '同步完成' : '同步沒有成功,稍後會自動重試');
            },
          ),
      ]),
      section('公用資料與版本', [
        ListTile(
          title: const Text('食材清單與單位'),
          subtitle: Text('需要登入 Google 才能更新公用資料。\n'
              '食材清單 ${catalog?.foodVersion ?? '-'}、單位 ${catalog?.unitVersion ?? '-'}\n最後檢查:${fmt(lastCheck)}'),
          isThreeLine: true,
        ),
        ListTile(
          title: const Text('檢查更新'),
          subtitle: Text(Env.backendConfigured
              ? '每天最多 10 次${raw[CheckKeys.checksLeft]?.isNotEmpty == true ? ',今天還有 ${raw[CheckKeys.checksLeft]} 次' : ''}'
              : '這個版本還沒設定後端網址'),
          trailing: _checking
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh_rounded),
          onTap: _checking || !Env.backendConfigured
              ? null
              : () async {
                  if (!await ensureSignedIn(context, services, '檢查公用資料的更新')) return;
                  setState(() => _checking = true);
                  final message = await services.check.run();
                  if (!mounted) return;
                  setState(() => _checking = false);
                  if (context.mounted) toast(context, message);
                },
        ),
        ListTile(title: const Text('App 版本'), subtitle: Text('${services.appVersion}(${services.buildNumber})')),
        ListTile(
          title: const Text('開放原始碼授權'),
          subtitle: const Text('本 App 使用的套件與字型(Noto Sans TC 等)的授權條款'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showLicensePage(
            context: context,
            applicationName: '媽媽記副食品',
            applicationVersion: services.appVersion,
          ),
        ),
      ]),
      if (kDebugMode)
        // 除錯工具只在 debug 版出現;release 版在編譯時就被移除(SPEC 第 2 節)。
        section('除錯工具(只有 debug 版)', [
          ListTile(title: const Text('故意當機(Dart)'), onTap: () => throw StateError('debug crash')),
          ListTile(title: const Text('故意當機(原生層)'), onTap: PlatformInfo.debugCrashNative),
          ListTile(title: const Text('故意無回應'), onTap: PlatformInfo.debugHangMainThread),
        ]),
      const DisclaimerText(Disclaimers.general),
    ]);
  }
}
