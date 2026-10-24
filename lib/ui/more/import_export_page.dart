import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/log.dart';
import '../../data/store.dart';
import '../../services/export_service.dart';
import '../../services/import_service.dart';
import '../../state/providers.dart';
import '../flows.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 匯入/匯出(SPEC 第 4 節、EXPORT_FORMAT_DRAFT.md)。需要登入 Google 與雲端硬碟權限。
class ImportExportPage extends ConsumerStatefulWidget {
  const ImportExportPage({super.key});

  @override
  ConsumerState<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends ConsumerState<ImportExportPage> {
  String? _step;

  bool get _busy => _step != null;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.all(12), children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('匯出', style: t.titleSmall),
          const SizedBox(height: 6),
          Text('把這支手機上全部寶寶的紀錄與照片,整份加密存到你的 Google 雲端硬碟「媽媽記副食品」資料夾。'
              '沒有紀錄也可以匯出(裡面有設定)。', style: t.bodyMedium),
          const SizedBox(height: 6),
          Text('匯出檔會整份加密(包含照片),只能用目前登入的 Google 帳號匯入。換了帳號就無法匯入,我們也無法幫你解開。',
              style: t.bodySmall!.copyWith(color: c.warn)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _busy ? null : _export, icon: const Icon(Icons.upload_rounded), label: const Text('匯出')),
        ]),
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('匯入', style: t.titleSmall),
          const SizedBox(height: 6),
          Text('選一個本 App 的匯出檔(.mff)。要用匯出時的 Google 帳號登入。同名的寶寶如果資料不一樣,'
              '可以選保留手機上的資料或用匯入檔取代;不同名的寶寶會新增。', style: t.bodyMedium),
          const SizedBox(height: 6),
          Text('匯入前會先關閉「紀錄與雲端同步」與「照片存到雲端」。匯入完成後請自行重新開啟,App 會再處理與雲端資料的差異。',
              style: t.bodySmall!.copyWith(color: c.warn)),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _busy ? null : _import, icon: const Icon(Icons.download_rounded), label: const Text('匯入')),
        ]),
      ),
      if (_busy) ...[
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text('$_step…', style: t.bodyMedium),
        ]),
      ],
      const DisclaimerText(Disclaimers.general),
    ]);
  }

  Future<void> _export() async {
    final services = ref.read(servicesProvider);
    if (!await ensureDrive(context, services, '匯出')) return;
    setState(() => _step = '準備');
    try {
      final result = await services.exporter.run(services.interactiveCloud(), progress: (s) {
        if (mounted) setState(() => _step = s);
      });
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('匯出完成'),
          content: Text('已存到雲端硬碟「媽媽記副食品」資料夾:\n${result.fileName}\n\n'
              '寶寶 ${result.babies} 個、紀錄 ${result.records} 筆、照片 ${result.photos} 張,已經讀回來檢查過。'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('好'))],
        ),
      );
    } on ExportProblem catch (e) {
      if (mounted) _problem('匯出沒有完成', e.message);
    } catch (e, st) {
      AppLog.error('export.error', e, st);
      if (mounted) _problem('匯出沒有完成', '匯出沒有成功,請再試一次。');
    } finally {
      if (mounted) setState(() => _step = null);
    }
  }

  Future<void> _import() async {
    final services = ref.read(servicesProvider);
    // 系統檔案選擇器改用一般檔案類型挑選,再由 App 檢查檔頭。
    final picked = await FilePicker.pickFiles(type: FileType.any);
    final path = picked.isEmpty ? null : picked.single.path;
    if (path == null || !mounted) return;
    final file = File(path);
    ImportPlan? plan;
    try {
      setState(() => _step = '檢查檔案');
      await services.importer.checkFile(file);
      if (!mounted) return;
      if (!await ensureDrive(context, services, '匯入')) return;
      plan = await services.importer.prepare(file, services.interactiveCloud(), progress: (s) {
        if (mounted) setState(() => _step = s);
      });
      if (!mounted) return;
      setState(() => _step = null);

      // 第 8 步:先說明,再關閉兩個雲端開關。
      final go = await confirm(context,
          title: '要匯入嗎?',
          message: '檔案裡有 ${plan.parsed.babies.length} 個寶寶、'
              '${plan.parsed.babies.fold<int>(0, (n, b) => n + b.records.length)} 筆紀錄。\n\n'
              '匯入前會先關閉「紀錄與雲端同步」與「照片存到雲端」。匯入完成後請自行重新開啟,App 會再處理與雲端資料的差異。',
          ok: '匯入');
      if (!go || !mounted) return;
      await services.store.setSetting(Keys.syncRecords, '0');
      await services.store.setSetting(Keys.syncPhotos, '0');

      // 第 9 步:同名寶寶有資料衝突 → 保留舊資料或匯入(直接取代);取代前要輸入寶寶名稱確認。
      final replace = <String, bool>{};
      for (final m in plan.conflicts) {
        if (!mounted) return;
        replace[m.file.name] = await _askReplace(m.file.name);
      }
      setState(() => _step = '寫入資料');
      final summary = await services.importer.apply(plan, replace);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('匯入完成'),
          content: Text('匯入了 ${summary.babies} 個寶寶、${summary.records} 筆紀錄'
              '${summary.skipped > 0 ? ',保留了 ${summary.skipped} 個寶寶在手機上的資料' : ''}。\n\n'
              '要同步的話,請到 App 設定重新打開「紀錄與雲端同步」與「照片存到雲端」。'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('好'))],
        ),
      );
    } on ImportProblem catch (e) {
      if (mounted) _problem('沒有匯入', e.message);
    } catch (e, st) {
      AppLog.error('import.error', e, st);
      if (mounted) _problem('沒有匯入', '匯入沒有成功,請再試一次。');
    } finally {
      if (plan != null) await services.importer.cleanup(plan);
      if (mounted) setState(() => _step = null);
    }
  }

  Future<bool> _askReplace(String name) async {
    final choice = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('「$name」的資料不一樣'),
        content: Text('手機上的「$name」和匯入檔裡的不一樣。要保留手機上的資料,還是用匯入檔直接取代(不做整合)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('匯入(取代)')),
          FilledButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('保留舊資料')),
        ],
      ),
    );
    if (choice != true || !mounted) return false;
    final controller = TextEditingController();
    final typed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('確定要取代嗎?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('手機上「$name」的紀錄會全部換成匯入檔的,無法復原。請輸入寶寶名稱「$name」確認。'),
            const SizedBox(height: 8),
            TextField(controller: controller, autofocus: true, onChanged: (_) => setState(() {})),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('保留舊資料')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ctx.colors.danger, foregroundColor: ctx.colors.bg),
              onPressed: controller.text.trim() == name ? () => Navigator.pop(ctx, true) : null,
              child: const Text('取代'),
            ),
          ],
        ),
      ),
    );
    return typed == true;
  }

  void _problem(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('好'))],
      ),
    );
  }
}
