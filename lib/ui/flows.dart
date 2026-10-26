import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log.dart';
import '../core/text.dart';
import '../core/time.dart';
import '../data/store.dart';
import '../domain/catalog.dart';
import '../domain/record.dart';
import '../services/auth_service.dart';
import '../services/drive_store.dart';
import '../services/feedback_service.dart';
import '../services/services.dart';
import '../services/sync_engine.dart';
import '../state/providers.dart';
import 'more/babies_page.dart';
import 'more/feedback_page.dart';
import 'shell.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// 需要使用者互動的流程(登入後的檢查、登出、開關雲端、刪除寶寶、同步衝突)。

/// 登入成功之後:換了帳號就自動關掉兩個雲端開關並提示(SPEC 第 4 節「換帳號」)。
Future<void> afterSignIn(BuildContext context, Services services) async {
  final user = services.auth.user;
  if (user == null) return;
  final store = services.store;
  final syncedAccount = await store.getSetting(SyncKeys.account);
  final recordsOn = await store.getSetting(Keys.syncRecords) == '1';
  final photosOn = await store.getSetting(Keys.syncPhotos) == '1';
  if (syncedAccount != null && syncedAccount != user.sub && (recordsOn || photosOn)) {
    await store.setSetting(Keys.syncRecords, '0');
    await store.setSetting(Keys.syncPhotos, '0');
    AppLog.info('auth.account_switched');
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('換了 Google 帳號'),
          content: const Text('這次登入的帳號和上次同步的帳號不同，已經先關閉「紀錄與雲端同步」和「照片存到雲端」。\n\n'
              '舊帳號雲端硬碟裡的照片，換帳號後看不到。要用這個帳號同步的話，請到 App 設定重新打開，'
              'App 會比對手機和雲端的資料。'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了'))],
        ),
      );
    }
  }
  await services.onForeground();
}

/// 登出:雲端開關開著時,先確認並說明影響;登出後兩個開關維持原設定,顯示「已暫停(未登入)」。
Future<void> signOutFlow(BuildContext context, Services services) async {
  final store = services.store;
  final cloudOn = await store.getSetting(Keys.syncRecords) == '1' || await store.getSetting(Keys.syncPhotos) == '1';
  if (cloudOn && context.mounted) {
    final ok = await confirm(context,
        title: '要登出嗎？',
        message: '登出後雲端同步會暫停：還沒上傳的修改與照片留在手機上，重新登入同一個帳號後會繼續上傳；'
            '已經存到雲端的照片，重新登入前看不到。',
        ok: '登出');
    if (!ok) return;
  }
  await services.auth.signOut();
}

/// 確保已登入。沒登入就先問要不要登入(SPEC 第 4 節:開啟任何雲端功能時,若未登入,先跳提醒並可跳轉登入)。
Future<bool> ensureSignedIn(BuildContext context, Services services, String why) async {
  if (services.auth.signedIn) return true;
  final go = await confirm(context, title: '需要登入', message: '$why需要先用 Google 帳號登入。', ok: '登入');
  if (!go) return false;
  try {
    await services.auth.signIn();
    if (context.mounted) await afterSignIn(context, services);
    return services.auth.signedIn;
  } catch (e) {
    if (context.mounted) toast(context, '登入沒有成功，請稍後再試');
    return false;
  }
}

/// 打開或關掉「紀錄與雲端同步」。打開時走「第一次開啟同步」的流程(多筆衝突對話框)。
Future<void> setRecordSync(BuildContext context, Services services, bool on) async {
  final store = services.store;
  if (!on) {
    await store.setSetting(Keys.syncRecords, '0');
    return;
  }
  if (!await ensureSignedIn(context, services, '紀錄與雲端同步')) return;
  try {
    await services.auth.driveAccessToken(interactive: true);
  } catch (_) {
    if (context.mounted) toast(context, '沒有取得雲端硬碟的權限，同步沒有打開');
    return;
  }
  await services.sync.startFresh(services.auth.user!.sub);
  await store.setSetting(Keys.syncRecords, '1');
  AppLog.info('sync.enabled');
  await services.sync.syncNow(reason: 'enabled');
}

/// 打開或關掉「照片存到雲端」。關掉只停止上傳新照片,已經在雲端的照片照常顯示。
Future<void> setPhotoSync(BuildContext context, Services services, bool on) async {
  final store = services.store;
  if (!on) {
    final ok = await confirm(context,
        title: '關閉照片存到雲端？',
        message: '之後的新照片只存在手機上。已經存到雲端的照片會留在雲端，登入同一個帳號時照常顯示。',
        ok: '關閉');
    if (ok) await store.setSetting(Keys.syncPhotos, '0');
    return;
  }
  if (!await ensureSignedIn(context, services, '照片存到雲端')) return;
  try {
    await services.auth.driveAccessToken(interactive: true);
  } catch (_) {
    if (context.mounted) toast(context, '沒有取得雲端硬碟的權限，照片雲端沒有打開');
    return;
  }
  await store.setSetting(Keys.syncPhotos, '1');
  await store.setSetting(SyncKeys.account, services.auth.user!.sub);
  AppLog.info('photos.cloud_enabled');
  services.photos.processCloud();
}

/// 改名(SPEC 第 15 節)。沒開雲端同步:直接改。有開同步:改名就是另一個寶寶,
/// 另外建立新名字的寶寶、複製目前的紀錄與照片,原本的寶寶保留。
Future<void> renameBabyFlow(BuildContext context, WidgetRef ref, Baby baby) async {
  final services = ref.read(servicesProvider);
  final store = services.store;
  final name = await askBabyName(context, title: '改名', initial: baby.name);
  if (name == null || name == baby.name || !context.mounted) return;
  final syncOn = await store.getSetting(Keys.syncRecords) == '1';
  try {
    if (!syncOn) {
      await store.renameBaby(baby.seq, name);
      return;
    }
    if (!context.mounted) return;
    final go = await confirm(context,
        title: '改名會變成另一個寶寶',
        message: '有開「紀錄與雲端同步」時，改名就是另一個寶寶：會另外建立「$name」，'
            '並把「${baby.name}」目前的紀錄與照片複製一份過去。\n\n'
            '原本的「${baby.name}」和它的紀錄會保留，不需要的話可以之後刪除。',
        ok: '建立「$name」');
    if (!go || !context.mounted) return;
    // 先確定每張照片都讀得到(可能只在雲端),讀不到就整個不做。
    final rows = await store.watchAll(baby.seq).first;
    final bytes = <String, List<int>>{};
    for (final id in [for (final r in rows) ...r.photoIds]) {
      final b = await services.photos.bytesOf(id);
      if (b == null) {
        if (context.mounted) toast(context, '有照片暫時讀不到（可能沒有網路），沒有改名');
        return;
      }
      bytes[id] = b;
    }
    final (copy, photos) = await store.copyBaby(baby.seq, name);
    for (final (oldId, newPhotoId, recordId) in photos) {
      await services.photos.importPhoto(newPhotoId, recordId, bytes[oldId]!);
    }
    await store.setSetting(Keys.currentBaby, '${copy.seq}');
    AppLog.info('baby.copied_on_rename', {'records': rows.length, 'photos': photos.length});
    if (context.mounted) toast(context, '已建立「$name」，複製了 ${rows.length} 筆紀錄；原本的「${baby.name}」保留著');
  } on InputProblem catch (e) {
    if (context.mounted) toast(context, e.message);
  } finally {
    services.sync.requestSoon();
  }
}

/// 刪除寶寶(SPEC 第 5 節):①警告通知按確定 → ②輸入「刪除{寶寶名}的紀錄」按確定 →
/// ③重新登入 Google(只有該寶寶在雲端有資料時才需要,而且必須是存放這些資料的同一個帳號),
/// 成功後執行並通知。確認視窗註明「已匯出的檔案不會被刪除」。
Future<void> deleteBabyFlow(BuildContext context, WidgetRef ref, Baby baby) async {
  final services = ref.read(servicesProvider);
  final store = services.store;
  final ok1 = await confirm(context,
      title: '刪除「${baby.name}」？',
      message: '「${baby.name}」的所有紀錄與照片都會刪除，而且無法復原。\n已匯出的檔案不會被刪除。',
      ok: '繼續',
      danger: true);
  if (!ok1 || !context.mounted) return;
  final phrase = '刪除${baby.name}的紀錄';
  final typed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final controller = TextEditingController();
      return StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('再確認一次'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('請輸入「$phrase」'),
            const SizedBox(height: 8),
            TextField(controller: controller, autofocus: true, onChanged: (_) => setState(() {})),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ctx.colors.danger, foregroundColor: ctx.colors.bg),
              onPressed: controller.text.trim() == phrase ? () => Navigator.pop(ctx, true) : null,
              child: const Text('刪除'),
            ),
          ],
        );
      });
    },
  );
  if (typed != true || !context.mounted) return;

  // 這個寶寶在雲端有沒有資料(紀錄或照片任一)。
  final db = store.db;
  final rows = await (db.select(db.records)..where((r) => r.babySeq.equals(baby.seq))).get();
  final photoIds = [for (final r in rows) if (r.photoIds.isNotEmpty) ...r.photoIds.split(',')];
  final cloudPhotos = await services.photos.cloudFileIds(photoIds);
  final syncedAccount = await store.getSetting(SyncKeys.account);
  final everSynced = rows.any((r) => r.cloudUpdatedAt != null) || syncedAccount != null && await store.getSetting(Keys.syncRecords) == '1';
  final hasCloud = cloudPhotos.isNotEmpty || everSynced;
  if (hasCloud) {
    if (!context.mounted) return;
    final relogin = await confirm(context,
        title: '重新登入 Google',
        message: '「${baby.name}」在雲端硬碟也有資料，要一起刪除。請重新登入存放這些資料的 Google 帳號。',
        ok: '登入');
    if (!relogin) return;
    try {
      await services.auth.signIn();
    } catch (_) {
      if (context.mounted) toast(context, '沒有登入，所以沒有刪除');
      return;
    }
    if (syncedAccount != null && services.auth.user?.sub != syncedAccount) {
      if (context.mounted) toast(context, '這不是存放這些資料的帳號，所以沒有刪除');
      return;
    }
    try {
      final CloudStore cloud = services.interactiveCloud();
      for (final f in await services.sync.cloudRecordsOfBaby(cloud, baby.seq)) {
        await cloud.delete(f.id);
      }
      for (final id in cloudPhotos) {
        await cloud.delete(id);
      }
    } catch (e) {
      AppLog.warn('baby.cloud_delete_failed', {'type': e.runtimeType.toString()});
      if (context.mounted) toast(context, '雲端的資料沒有刪成功，請確認網路後再試；手機上的資料還在');
      return;
    }
  }
  final removed = await store.deleteBabyLocal(baby.seq);
  await services.photos.deleteLocalFiles(removed);
  AppLog.info('baby.deleted', {'cloud': hasCloud});
  services.sync.requestSoon();
  if (context.mounted) toast(context, '已刪除「${baby.name}」的紀錄');
}

/// 同步衝突(SPEC 第 4 節):只有一筆 → 顯示差異,選保留哪一邊;多筆 → 四個選項,
/// 覆蓋類的選項按下前再多一層確認。
Future<ConflictChoice> resolveConflicts(BuildContext context, Catalog? catalog, List<SyncConflict> conflicts) async {
  if (conflicts.length == 1) {
    final c = conflicts.first;
    String describe(FeedRecord? r) {
      if (r == null) return '（已刪除）';
      final food = catalog?.food(r.foodId);
      final t = r.localTime;
      return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
          ' ${food?.emoji ?? ''}${food?.name ?? ''}\n食用量 ${Amount.format(r.eatenCenti)}'
          '${r.note.isEmpty ? '' : '\n備註：${r.note}'}';
    }

    final keepLocal = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('有一筆資料與雲端衝突'),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('手機上的：'),
            Text(describe(c.local)),
            const SizedBox(height: 12),
            const Text('雲端的：'),
            Text(describe(c.remote)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('保留雲端的')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保留手機上的')),
        ],
      ),
    );
    return keepLocal == true ? ConflictChoice.localWins : ConflictChoice.cloudWins;
  }
  while (true) {
    if (!context.mounted) return ConflictChoice.keepNewer;
    final choice = await showDialog<ConflictChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SimpleDialog(
        title: Text('你有 ${conflicts.length} 筆資料與雲端衝突，無法同步'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('衝突的日期：${conflictDaysText(conflicts)}\n可以先選「關閉雲端同步記錄」自己修改；'
                '最快的做法是「以雲端覆蓋本機」。'),
          ),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, ConflictChoice.keepNewer), child: const Text('每筆保留較新的（建議）')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, ConflictChoice.localWins), child: const Text('以本機覆蓋雲端')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, ConflictChoice.cloudWins), child: const Text('以雲端覆蓋本機')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, ConflictChoice.stopSync), child: const Text('關閉雲端同步記錄')),
        ],
      ),
    );
    if (choice == null) continue;
    if (choice == ConflictChoice.localWins || choice == ConflictChoice.cloudWins) {
      if (!context.mounted) return ConflictChoice.keepNewer;
      final sure = await confirm(context,
          title: '確定嗎？',
          message: choice == ConflictChoice.localWins ? '衝突的資料會全部以手機上的為準，雲端的那份會被蓋掉。' : '衝突的資料會全部以雲端的為準，手機上的那份會被蓋掉。',
          ok: '確定',
          danger: true);
      if (!sure) continue;
    }
    return choice;
  }
}

/// 衝突的日期(SPEC 第 15 節):手機上與雲端那份的日期都算,從舊到新,最多列 10 個。
String conflictDaysText(List<SyncConflict> conflicts, {int max = 10}) {
  final days = <Day>{
    for (final c in conflicts) ...[c.local.day, if (c.remote != null) c.remote!.day],
  }.toList()
    ..sort();
  final shown = days.take(max).map((d) => '${d.year}/${d.month}/${d.day}').join('、');
  return days.length > max ? '$shown 等共 ${days.length} 天' : shown;
}

/// 不跳畫面的同步(背景)遇到衝突或預期外的狀況時,用最上層的畫面問使用者。
void installConflictResolver(Services services, GlobalKey<NavigatorState> navigator, WidgetRef ref) {
  services.sync.resolver = (conflicts) async {
    final context = navigator.currentContext;
    if (context == null) return ConflictChoice.keepNewer;
    return resolveConflicts(context, ref.read(catalogProvider).value, conflicts);
  };
  var shown = false;
  services.sync.onMergeProblem = (_) async {
    // 每次開 App 只說一次;之後的同步遇到同樣的狀況,設定頁會顯示。
    if (shown) return;
    final context = navigator.currentContext;
    if (context == null || !context.mounted) return;
    shown = true;
    await showIntegrationProblem(context, ref);
  };
}

/// 資料整合(同步或匯入)遇到預期外的狀況:說明手機上的資料沒動,並在同一個視窗提供回報。
/// 相關資訊已經寫進診斷記錄,回報時會一起送出。
Future<void> showIntegrationProblem(BuildContext context, WidgetRef ref) async {
  final report = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('資料整合出現問題'),
      content: const Text('合併資料時遇到預期外的狀況，這次沒有完成，手機上的資料沒有變動。\n\n'
          '相關資訊已經記下來了，回報給我們可以幫助我們修正。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('關閉')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('回報錯誤')),
      ],
    ),
  );
  if (report != true) return;
  final shell = ref.read(shellProvider.notifier);
  while (shell.pop()) {}
  shell.push(SubPage('意見回饋', (_) => const FeedbackPage(kind: FeedbackKind.problem)));
}

/// 需要雲端硬碟權限的操作前用:先確定登入、再要權限。
Future<bool> ensureDrive(BuildContext context, Services services, String why) async {
  if (!await ensureSignedIn(context, services, why)) return false;
  try {
    await services.auth.driveAccessToken(interactive: true);
    return true;
  } on NotSignedIn {
    return false;
  } catch (_) {
    if (context.mounted) toast(context, '沒有取得雲端硬碟的權限');
    return false;
  }
}
