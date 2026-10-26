import 'dart:async';
import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/log.dart';
import '../core/time.dart';
import '../data/database.dart';
import '../data/store.dart';
import '../domain/record.dart';
import 'drive_store.dart';
import 'export_format.dart';

/// 雲端上的檔案(都在 App 專用區,使用者看不到):
///
///     mff_manifest.json      版本(每次同步成功寫入新的時間戳)
///     mff_babies.json        寶寶清單(含刪除標記)
///     mff_rec_{UUID}.json    每筆紀錄一個檔(縮小衝突範圍)
///
/// 每個紀錄檔的 appProperties 帶 u(最後修改時間)、d(是否刪除)、b(寶寶序號),
/// 不必下載內容就能比對。
abstract final class CloudNames {
  static const manifest = 'mff_manifest.json';
  static const babies = 'mff_babies.json';
  static const recordPrefix = 'mff_rec_';

  static String record(String id) => '$recordPrefix$id.json';
}

abstract final class SyncKeys {
  static const base = 'sync_base';
  static const pending = 'sync_pending';
  static const account = 'sync_account';
  static const first = 'sync_first';
  static const lastOk = 'sync_last_ok';
  static const lastError = 'sync_last_error';
}

/// 多筆衝突時的四個選項(SPEC 第 4 節);只有一筆時是「保留手機上的/保留雲端的」。
enum ConflictChoice { keepNewer, localWins, cloudWins, stopSync }

class SyncConflict {
  const SyncConflict({required this.local, required this.remote, required this.remoteUpdatedAt});

  final FeedRecord local;

  /// 雲端那一份(已刪除時為 null)。
  final FeedRecord? remote;
  final int remoteUpdatedAt;
}

typedef ConflictResolver = Future<ConflictChoice> Function(List<SyncConflict> conflicts);

enum SyncState { off, idle, syncing, ok, failed }

class _RemoteRecord {
  _RemoteRecord(this.file)
      : updatedAt = int.tryParse(file.props['u'] ?? '') ?? 0,
        deleted = file.props['d'] == '1';

  final CloudFile file;
  final int updatedAt;
  final bool deleted;
}

/// 雲端同步(SPEC 第 4 節「版本比對」「衝突處理」)。
///
/// - 雲端版本 = 基礎版本 → 沒人動過:上傳,再讀一次雲端確認;確認成功才清掉本機暫存。
/// - 雲端版本 = 上次要寫的版本 → 上次其實傳成功:比對一致才清掉。
/// - 其他 → 有人動過:逐筆比對,無衝突的自動合併;有衝突交給使用者選。
/// - 失敗重試:5 分鐘一次、半天上限 10 次,只在 App 開著時;**沒成功絕不刪本機**。
/// - 一切以單一支手機為優先,第二支手機造成的衝突只求堪用。
class SyncEngine extends ChangeNotifier {
  SyncEngine({required this.store, required this.cloud, required this.enabled});

  final Store store;
  final CloudStore? Function() cloud;
  final Future<bool> Function() enabled;
  ConflictResolver? resolver;

  SyncState state = SyncState.idle;

  /// 測試用:直接設定狀態並通知畫面(真的同步要連雲端硬碟)。
  @visibleForTesting
  void debugSetState(SyncState value) {
    state = value;
    notifyListeners();
  }
  DateTime? _lastAttempt;
  Future<void>? _running;
  Timer? _retry;
  Timer? _soon;
  int _retries = 0;
  DateTime _retryWindow = DateTime.now();

  AppDb get _db => store.db;

  int _now() => TimeRules.now().toUtc().millisecondsSinceEpoch;

  /// 開 App 或從背景回來時呼叫;一分鐘內不重複。
  void onForeground() {
    final last = _lastAttempt;
    if (last != null && DateTime.now().difference(last) < Timing.syncMinInterval) return;
    unawaited(syncNow(reason: 'foreground'));
  }

  /// 本機有修改時呼叫:稍等一下再同步(連續修改只同步一次)。
  void requestSoon() {
    _soon?.cancel();
    _soon = Timer(const Duration(seconds: 8), () => unawaited(syncNow(reason: 'local_change')));
  }

  /// 第一次開啟同步(或換帳號、匯入之後重新打開):走「第一次同步」的流程。
  Future<void> startFresh(String accountSub) async {
    await store.setSetting(SyncKeys.first, '1');
    await store.setSetting(SyncKeys.base, null);
    await store.setSetting(SyncKeys.pending, null);
    await store.setSetting(SyncKeys.account, accountSub);
  }

  Future<void> syncNow({required String reason}) {
    final running = _running;
    if (running != null) return running;
    final f = _guarded(reason).whenComplete(() => _running = null);
    _running = f;
    return f;
  }

  Future<void> _guarded(String reason) async {
    if (!await enabled()) {
      state = SyncState.off;
      notifyListeners();
      return;
    }
    final c = cloud();
    if (c == null) {
      state = SyncState.idle;
      notifyListeners();
      return;
    }
    _lastAttempt = DateTime.now();
    state = SyncState.syncing;
    notifyListeners();
    AppLog.info('sync.start', {'reason': reason});
    try {
      // 一輪同步最多 10 分鐘;每個雲端硬碟操作本身也有上限(drive_store.dart)。
      for (var round = 0; round < 3; round++) {
        if (await _round(c).timeout(const Duration(minutes: 10))) break;
      }
      state = SyncState.ok;
      _retries = 0;
      await store.setSetting(SyncKeys.lastOk, '${_now()}');
      await store.setSetting(SyncKeys.lastError, null);
      AppLog.info('sync.ok');
    } on SyncStopped {
      // 使用者在衝突對話框選了「關閉雲端同步記錄」:不是錯誤,也不重試。
      state = SyncState.off;
      AppLog.info('sync.stopped_by_user');
    } catch (e, st) {
      state = SyncState.failed;
      await store.setSetting(SyncKeys.lastError, e is CloudError ? e.kind : e.runtimeType.toString());
      AppLog.error('sync.failed', e, st);
      _scheduleRetry();
    }
    notifyListeners();
  }

  void _scheduleRetry() {
    final now = DateTime.now();
    if (now.difference(_retryWindow) > const Duration(hours: 12)) {
      _retryWindow = now;
      _retries = 0;
    }
    if (_retries >= Timing.syncRetriesPerHalfDay) return;
    _retries += 1;
    _retry?.cancel();
    _retry = Timer(Timing.syncRetryInterval, () => unawaited(syncNow(reason: 'retry')));
  }

  /// 一輪同步。回傳 true 表示完成;false 表示寫入時被別的手機搶先,要再跑一輪。
  Future<bool> _round(CloudStore c) async {
    final files = await c.listAppData('mff_');
    final manifest = files.where((f) => f.name == CloudNames.manifest).firstOrNull;
    final babiesFile = files.where((f) => f.name == CloudNames.babies).firstOrNull;
    final remote = <String, _RemoteRecord>{
      for (final f in files)
        if (f.name.startsWith(CloudNames.recordPrefix) && f.name.endsWith('.json'))
          f.name.substring(CloudNames.recordPrefix.length, f.name.length - 5): _RemoteRecord(f),
    };
    final cloudVersion = manifest?.props['v'];
    final base = await store.getSetting(SyncKeys.base);
    final pending = await store.getSetting(SyncKeys.pending);
    final first = await store.getSetting(SyncKeys.first) == '1' || base == null;

    var babiesChanged = await _mergeBabies(c, babiesFile);

    if (!first && cloudVersion == base) {
      // 沒人動過:只要上傳。
    } else if (!first && cloudVersion != null && cloudVersion == pending) {
      // 上次其實傳成功了:雲端和本機一致的,清掉暫存。
      await _markLanded(remote);
    } else {
      await _merge(c, remote, first: first);
    }

    final dirty = await (_db.select(_db.records)..where((r) => r.dirty.equals(true))).get();
    final dirtyBabies = await (_db.select(_db.babies)..where((b) => b.dirty.equals(true))).get();
    babiesChanged = babiesChanged || dirtyBabies.isNotEmpty || babiesFile == null;
    if (dirty.isEmpty && !babiesChanged && manifest != null) {
      // 沒有要上傳的:記下目前的雲端版本就好。
      await _finish(cloudVersion);
      return true;
    }

    final previous = int.tryParse(cloudVersion ?? '') ?? 0;
    final version = '${_now() > previous ? _now() : previous + 1}';
    await store.setSetting(SyncKeys.pending, version);

    final uploaded = <String, int>{};
    for (final row in dirty) {
      final bytes = _encodeRecord(row);
      final props = {'u': '${row.updatedAt}', 'd': row.deleted ? '1' : '0', 'b': '${row.babySeq}'};
      final existing = remote[row.id]?.file;
      if (existing == null) {
        await c.createAppData(CloudNames.record(row.id), bytes, props: props);
      } else {
        await c.updateAppData(existing.id, bytes, props: props);
      }
      uploaded[row.id] = row.updatedAt;
    }
    if (babiesChanged) {
      final all = await _db.select(_db.babies).get();
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'babies': [
          for (final b in all)
            {'seq': b.seq, 'name': b.name, 'created_at': b.createdAt, 'updated_at': b.updatedAt, 'deleted': b.deleted},
        ],
      })));
      if (babiesFile == null) {
        await c.createAppData(CloudNames.babies, bytes);
      } else {
        await c.updateAppData(babiesFile.id, bytes);
      }
    }
    final manifestBytes = Uint8List.fromList(utf8.encode(jsonEncode({'version': version})));
    if (manifest == null) {
      await c.createAppData(CloudNames.manifest, manifestBytes, props: {'v': version});
    } else {
      await c.updateAppData(manifest.id, manifestBytes, props: {'v': version});
    }

    // 再讀一次雲端確認;確認成功才清掉本機暫存。
    final check = (await c.listAppData(CloudNames.manifest)).where((f) => f.name == CloudNames.manifest).firstOrNull;
    if (check?.props['v'] != version) {
      AppLog.warn('sync.manifest_race');
      return false;
    }
    await _db.transaction(() async {
      for (final e in uploaded.entries) {
        // 上傳之後又被改過的,留著下次再傳。
        await (_db.update(_db.records)..where((r) => r.id.equals(e.key) & r.updatedAt.equals(e.value)))
            .write(RecordsCompanion(dirty: const Value(false), cloudUpdatedAt: Value(e.value)));
      }
      for (final b in dirtyBabies) {
        await (_db.update(_db.babies)..where((x) => x.seq.equals(b.seq) & x.updatedAt.equals(b.updatedAt)))
            .write(BabiesCompanion(dirty: const Value(false), cloudUpdatedAt: Value(b.updatedAt)));
      }
    });
    await _finish(version);
    AppLog.info('sync.uploaded', {'records': uploaded.length, 'babies': babiesChanged});
    return true;
  }

  Future<void> _finish(String? version) async {
    await store.setSetting(SyncKeys.base, version);
    await store.setSetting(SyncKeys.pending, null);
    await store.setSetting(SyncKeys.first, null);
  }

  Uint8List _encodeRecord(RecordRow row) {
    final r = recordFromRow(row);
    return Uint8List.fromList(utf8.encode(jsonEncode({
      ...ExportFormat.encodeRecord(r, photosAsPaths: false),
      'baby_seq': row.babySeq,
      'deleted': row.deleted,
    })));
  }

  Future<FeedRecord?> _download(CloudStore c, _RemoteRecord r) async {
    if (r.deleted) return null;
    final json = (jsonDecode(utf8.decode(await c.readAppData(r.file.id))) as Map).cast<String, Object?>();
    final seq = json['baby_seq'];
    if (seq is! int) throw const FormatException('雲端紀錄的寶寶序號不對');
    final clean = Map<String, Object?>.of(json)
      ..remove('baby_seq')
      ..remove('deleted');
    return ExportFormat.decodeRecord(clean, babySeq: seq, photosAsPaths: false);
  }

  Future<void> _writeRemote(FeedRecord? r, String id, int remoteUpdatedAt) async {
    if (r == null) {
      // 雲端那份是刪除標記:手機上也標記刪除。
      await (_db.update(_db.records)..where((x) => x.id.equals(id))).write(RecordsCompanion(
          deleted: const Value(true), dirty: const Value(false), cloudUpdatedAt: Value(remoteUpdatedAt), photoIds: const Value('')));
      return;
    }
    await _db.into(_db.records).insertOnConflictUpdate(RecordsCompanion.insert(
          id: r.id,
          babySeq: r.babySeq,
          timeUtc: r.timeUtcMs,
          tzOffset: r.tzOffsetMinutes,
          localDay: '${r.day}',
          foodId: r.foodId,
          preparedCenti: r.preparedCenti,
          preparedUnitId: r.preparedUnitId,
          eatenCenti: r.eatenCenti,
          eatenUnitId: r.eatenUnitId,
          allergy: Value(r.allergy?.code),
          reaction: Value(r.reaction?.code),
          note: Value(r.note),
          photoIds: Value(r.photoIds.join(',')),
          createdAt: r.createdAtMs,
          updatedAt: remoteUpdatedAt,
          deleted: const Value(false),
          dirty: const Value(false),
          cloudUpdatedAt: Value(remoteUpdatedAt),
        ));
  }

  Future<void> _markLanded(Map<String, _RemoteRecord> remote) async {
    final dirty = await (_db.select(_db.records)..where((r) => r.dirty.equals(true))).get();
    for (final row in dirty) {
      final r = remote[row.id];
      if (r != null && r.updatedAt == row.updatedAt) {
        await (_db.update(_db.records)..where((x) => x.id.equals(row.id) & x.updatedAt.equals(row.updatedAt)))
            .write(RecordsCompanion(dirty: const Value(false), cloudUpdatedAt: Value(r.updatedAt)));
      }
    }
  }

  /// 逐筆比對。無衝突的自動合併;衝突交給使用者選(SPEC 第 4 節)。
  Future<void> _merge(CloudStore c, Map<String, _RemoteRecord> remote, {required bool first}) async {
    final locals = {for (final r in await _db.select(_db.records).get()) r.id: r};
    final conflicts = <(RecordRow, _RemoteRecord)>[];
    var pulled = 0;
    for (final entry in remote.entries) {
      final r = entry.value;
      final local = locals[entry.key];
      if (local == null) {
        if (r.deleted) continue; // 在別支手機新增又刪掉的,這支手機沒看過,不用管
        await _writeRemote(await _download(c, r), entry.key, r.updatedAt);
        pulled++;
        continue;
      }
      final known = first ? null : local.cloudUpdatedAt;
      if (known == null) {
        if (local.updatedAt == r.updatedAt && local.deleted == r.deleted) {
          await (_db.update(_db.records)..where((x) => x.id.equals(local.id)))
              .write(RecordsCompanion(dirty: const Value(false), cloudUpdatedAt: Value(r.updatedAt)));
        } else {
          conflicts.add((local, r));
        }
      } else if (known == r.updatedAt) {
        // 雲端沒變;本機有改的話等一下上傳。
      } else if (!local.dirty) {
        await _writeRemote(await _download(c, r), entry.key, r.updatedAt);
        pulled++;
      } else {
        conflicts.add((local, r));
      }
    }
    // 雲端沒有、手機上有的:上傳(雲端檔案不見了也不刪手機上的,重新傳上去)。
    for (final local in locals.values) {
      if (!remote.containsKey(local.id) && !local.dirty && !(local.deleted && local.cloudUpdatedAt == null)) {
        await (_db.update(_db.records)..where((x) => x.id.equals(local.id))).write(const RecordsCompanion(dirty: Value(true)));
      }
    }
    if (pulled > 0) AppLog.info('sync.pulled', {'n': pulled});
    if (conflicts.isEmpty) return;

    final list = <SyncConflict>[];
    for (final (local, r) in conflicts) {
      list.add(SyncConflict(local: recordFromRow(local), remote: await _download(c, r), remoteUpdatedAt: r.updatedAt));
    }
    AppLog.info('sync.conflicts', {'n': list.length});
    final ask = resolver;
    final choice = ask == null ? ConflictChoice.keepNewer : await ask(list);
    AppLog.info('sync.conflict_choice', {'choice': choice});
    if (choice == ConflictChoice.stopSync) {
      await store.setSetting(Keys.syncRecords, '0');
      throw const SyncStopped();
    }
    for (var i = 0; i < list.length; i++) {
      final conflict = list[i];
      final (local, r) = conflicts[i];
      final takeRemote = switch (choice) {
        ConflictChoice.cloudWins => true,
        ConflictChoice.localWins => false,
        _ => r.updatedAt > local.updatedAt,
      };
      if (takeRemote) {
        await _writeRemote(conflict.remote, local.id, r.updatedAt);
      } else {
        // 手機上的贏:記下看過的雲端版本,保持 dirty,等一下覆蓋雲端。
        await (_db.update(_db.records)..where((x) => x.id.equals(local.id)))
            .write(RecordsCompanion(dirty: const Value(true), cloudUpdatedAt: Value(r.updatedAt)));
      }
    }
  }

  /// 寶寶清單的合併。寶寶以序號加建立時間辨識;兩支手機離線時各自新增而撞號,
  /// 後到的(這支手機上、雲端還沒有的)自動改用下一個沒用過的序號。
  Future<bool> _mergeBabies(CloudStore c, CloudFile? file) async {
    if (file == null) return false;
    final json = (jsonDecode(utf8.decode(await c.readAppData(file.id))) as Map).cast<String, Object?>();
    final remote = [for (final b in (json['babies'] as List? ?? const [])) (b as Map).cast<String, Object?>()];
    var changed = false;
    for (final rb in remote) {
      final seq = rb['seq'] as int;
      final createdAt = rb['created_at'] as int;
      final updatedAt = rb['updated_at'] as int;
      final deleted = rb['deleted'] == true;
      final name = rb['name'] as String;
      final local = await (_db.select(_db.babies)..where((b) => b.seq.equals(seq))).getSingleOrNull();
      if (local == null) {
        await _db.into(_db.babies).insert(BabiesCompanion.insert(
            seq: Value(seq), name: name, createdAt: createdAt, updatedAt: updatedAt, deleted: Value(deleted),
            cloudUpdatedAt: Value(updatedAt)));
        await _bumpSeqMax(seq);
        continue;
      }
      if (local.createdAt != createdAt) {
        // 撞號:手機上的這個改用新序號,紀錄跟著改,再放進雲端那個。
        final newSeq = await _freeSeq();
        await _db.transaction(() async {
          await _db.into(_db.babies).insert(local.copyWith(seq: newSeq, dirty: true, cloudUpdatedAt: const Value(null)));
          await (_db.update(_db.records)..where((r) => r.babySeq.equals(seq)))
              .write(RecordsCompanion(babySeq: Value(newSeq), dirty: const Value(true), updatedAt: Value(_now())));
          await (_db.delete(_db.babies)..where((b) => b.seq.equals(seq) & b.createdAt.equals(local.createdAt))).go();
          await _db.into(_db.babies).insert(BabiesCompanion.insert(
              seq: Value(seq), name: name, createdAt: createdAt, updatedAt: updatedAt, deleted: Value(deleted),
              cloudUpdatedAt: Value(updatedAt)));
        });
        await _bumpSeqMax(newSeq);
        AppLog.info('sync.baby_renumbered');
        changed = true;
        continue;
      }
      final remoteChanged = updatedAt != (local.cloudUpdatedAt ?? -1);
      if (!remoteChanged) continue;
      final takeRemote = !local.dirty || updatedAt > local.updatedAt;
      if (!takeRemote) continue;
      if (deleted && !local.deleted) {
        // 別支手機刪了這個寶寶(那邊已經過三步確認):這支手機也刪。
        await store.deleteBabyLocal(seq);
        await (_db.update(_db.babies)..where((b) => b.seq.equals(seq)))
            .write(BabiesCompanion(dirty: const Value(false), updatedAt: Value(updatedAt), cloudUpdatedAt: Value(updatedAt)));
        AppLog.info('sync.baby_deleted_remotely');
        continue;
      }
      await (_db.update(_db.babies)..where((b) => b.seq.equals(seq))).write(BabiesCompanion(
          name: Value(name), deleted: Value(deleted), updatedAt: Value(updatedAt), dirty: const Value(false),
          cloudUpdatedAt: Value(updatedAt)));
    }
    await _fixDuplicateNames();
    return changed;
  }

  Future<int> _freeSeq() async {
    final rows = await _db.select(_db.babies).get();
    final maxInTable = rows.fold<int>(0, (m, b) => b.seq > m ? b.seq : m);
    final remembered = int.tryParse(await store.getSetting(Keys.babySeqMax) ?? '') ?? 0;
    return (maxInTable > remembered ? maxInTable : remembered) + 1;
  }

  Future<void> _bumpSeqMax(int seq) async {
    final remembered = int.tryParse(await store.getSetting(Keys.babySeqMax) ?? '') ?? 0;
    if (seq > remembered) await store.setSetting(Keys.babySeqMax, '$seq');
  }

  /// 合併後如果有同名的寶寶(名稱不可重複),後面的那個加上編號。
  Future<void> _fixDuplicateNames() async {
    final live = await (_db.select(_db.babies)
          ..where((b) => b.deleted.equals(false))
          ..orderBy([(b) => OrderingTerm.asc(b.seq)]))
        .get();
    final seen = <String>{};
    for (final b in live) {
      if (seen.add(b.name)) continue;
      var n = 2;
      String candidate;
      do {
        final suffix = '($n)';
        final room = Limits.babyNameMaxChars - suffix.length;
        candidate = '${b.name.characters.take(room)}$suffix';
        n++;
      } while (seen.contains(candidate));
      seen.add(candidate);
      await (_db.update(_db.babies)..where((x) => x.seq.equals(b.seq)))
          .write(BabiesCompanion(name: Value(candidate), dirty: const Value(true), updatedAt: Value(_now())));
    }
  }

  /// 進入修改前先確認雲端的版本(SPEC 第 4、7 節)。雲端比較新而且手機上沒有未上傳的修改,
  /// 就先拉回來。回傳 true 表示手機上的內容被更新了。最多等 8 秒,連不上就用手機上的。
  Future<bool> refreshBeforeEdit(String recordId) async {
    if (!await enabled()) return false;
    final c = cloud();
    if (c == null) return false;
    try {
      return await Future(() async {
        final files = await c.listAppData(CloudNames.record(recordId));
        final f = files.where((x) => x.name == CloudNames.record(recordId)).firstOrNull;
        if (f == null) return false;
        final r = _RemoteRecord(f);
        final local = await (_db.select(_db.records)..where((x) => x.id.equals(recordId))).getSingleOrNull();
        if (local == null || local.dirty || local.cloudUpdatedAt == r.updatedAt) return false;
        await _writeRemote(await _download(c, r), recordId, r.updatedAt);
        AppLog.info('sync.refreshed_before_edit');
        return true;
      }).timeout(const Duration(seconds: 8));
    } catch (e) {
      AppLog.warn('sync.refresh_failed', {'type': e.runtimeType.toString()});
      return false;
    }
  }

  /// 刪除寶寶時:雲端上屬於這個寶寶的紀錄檔(有開同步時)。
  Future<List<CloudFile>> cloudRecordsOfBaby(CloudStore c, int seq) async {
    final files = await c.listAppData(CloudNames.recordPrefix);
    return [for (final f in files) if (f.props['b'] == '$seq') f];
  }

  @override
  void dispose() {
    _retry?.cancel();
    _soon?.cancel();
    super.dispose();
  }
}

class SyncStopped implements Exception {
  const SyncStopped();

  @override
  String toString() => '已關閉紀錄同步';
}
