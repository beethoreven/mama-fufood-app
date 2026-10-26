import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/constants.dart';
import '../core/text.dart';
import '../core/time.dart';
import '../domain/catalog.dart';
import '../domain/record.dart';
import 'database.dart';

class Baby {
  const Baby({required this.seq, required this.name, required this.createdAt});

  final int seq;
  final String name;
  final int createdAt;
}

/// 使用者輸入不合規則時丟出;訊息直接顯示給使用者。
class InputProblem implements Exception {
  const InputProblem(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 設定的鍵。值一律存字串。
abstract final class Keys {
  static const weekStart = 'week_start'; // monday | sunday(預設星期一)
  static const theme = 'theme'; // dark | light | system(預設深色)
  static const syncRecords = 'sync_records';
  static const syncPhotos = 'sync_photos';
  static const currentBaby = 'current_baby';
  static const babySeqMax = 'baby_seq_max';
  static const policyAck = 'policy_ack';
  static const pickerApplyMs = 'picker_apply_ms'; // 捲動選單放手後幾毫秒選定(只存在這支手機,不匯出、不同步)
  static const pickerIdleMs = 'picker_idle_ms'; // 捲動選單沒動幾毫秒選定(同上)
}

FeedRecord recordFromRow(RecordRow row) => FeedRecord(
      id: row.id,
      babySeq: row.babySeq,
      timeUtcMs: row.timeUtc,
      tzOffsetMinutes: row.tzOffset,
      foodId: row.foodId,
      preparedCenti: row.preparedCenti,
      preparedUnitId: row.preparedUnitId,
      eatenCenti: row.eatenCenti,
      eatenUnitId: row.eatenUnitId,
      allergy: Allergy.fromCode(row.allergy),
      reaction: Reaction.fromCode(row.reaction),
      digestive: Digestive.fromCode(row.digestive),
      note: row.note,
      photoIds: row.photoIds.isEmpty ? const [] : row.photoIds.split(','),
      createdAtMs: row.createdAt,
      updatedAtMs: row.updatedAt,
    );

/// 本機資料的讀寫都經過這裡。
class Store {
  Store(this.db);

  final AppDb db;

  int _now() => TimeRules.now().toUtc().millisecondsSinceEpoch;

  // ── 設定 ────────────────────────────────────────────────

  Future<String?> getSetting(String key) async =>
      (await (db.select(db.settings)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      await (db.delete(db.settings)..where((s) => s.key.equals(key))).go();
    } else {
      await db.into(db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
    }
  }

  Stream<Map<String, String>> watchSettings() =>
      db.select(db.settings).watch().map((rows) => {for (final r in rows) r.key: r.value});

  Future<Map<String, String>> allSettings() async =>
      {for (final r in await db.select(db.settings).get()) r.key: r.value};

  // ── 公用資料 ────────────────────────────────────────────

  Future<DatasetEnvelope?> getDataset(String name) async {
    final row = await (db.select(db.datasets)..where((d) => d.name.equals(name))).getSingleOrNull();
    if (row == null) return null;
    return DatasetEnvelope(
        name: row.name, version: row.version, formatVersion: row.formatVersion,
        content: (jsonDecode(row.content) as Map).cast<String, dynamic>());
  }

  Future<void> putDataset(DatasetEnvelope env) => db.into(db.datasets).insertOnConflictUpdate(DatasetsCompanion.insert(
      name: env.name, version: env.version, formatVersion: env.formatVersion, content: jsonEncode(env.content)));

  Stream<void> watchDatasets() => db.select(db.datasets).watch().map((_) {});

  // ── 寶寶 ────────────────────────────────────────────────

  Stream<List<Baby>> watchBabies() => (db.select(db.babies)
        ..where((b) => b.deleted.equals(false))
        ..orderBy([(b) => OrderingTerm.asc(b.seq)]))
      .watch()
      .map((rows) => [for (final r in rows) Baby(seq: r.seq, name: r.name, createdAt: r.createdAt)]);

  Future<List<Baby>> babies() => watchBabies().first;

  /// 名稱最多 20 字、不可重複、最多 8 個寶寶(SPEC 第 5 節)。
  Future<String> _checkName(String raw, {int? exceptSeq}) async {
    final name = raw.trim();
    if (name.isEmpty) throw const InputProblem('請輸入寶寶名稱');
    if (charCount(name) > Limits.babyNameMaxChars) {
      throw const InputProblem('名稱最多 ${Limits.babyNameMaxChars} 個字');
    }
    final same = (await babies()).where((b) => b.name == name && b.seq != exceptSeq);
    if (same.isNotEmpty) throw const InputProblem('已經有同名的寶寶了，要的話可以加上編號');
    return name;
  }

  Future<Baby> addBaby(String rawName) async {
    final name = await _checkName(rawName);
    return db.transaction(() async {
      if ((await babies()).length >= Limits.maxBabies) {
        throw const InputProblem('最多只能記錄 ${Limits.maxBabies} 個寶寶');
      }
      final seq = await _nextBabySeq();
      final now = _now();
      await db.into(db.babies).insert(BabiesCompanion.insert(
          seq: Value(seq), name: name, createdAt: now, updatedAt: now, dirty: const Value(true)));
      await setSetting(Keys.babySeqMax, '$seq');
      return Baby(seq: seq, name: name, createdAt: now);
    });
  }

  /// 下一個沒用過的序號:刪除後不重複使用。
  Future<int> _nextBabySeq() async {
    final maxRow = await (db.selectOnly(db.babies)..addColumns([db.babies.seq.max()])).getSingle();
    final inTable = maxRow.read(db.babies.seq.max()) ?? 0;
    final remembered = int.tryParse(await getSetting(Keys.babySeqMax) ?? '') ?? 0;
    return (inTable > remembered ? inTable : remembered) + 1;
  }

  Future<void> renameBaby(int seq, String rawName) async {
    final name = await _checkName(rawName, exceptSeq: seq);
    await (db.update(db.babies)..where((b) => b.seq.equals(seq)))
        .write(BabiesCompanion(name: Value(name), updatedAt: Value(_now()), dirty: const Value(true)));
  }

  /// 有開雲端同步時改名(SPEC 第 15 節):改名就是另一個寶寶。建立新名字的寶寶,把紀錄複製一份
  /// (新的紀錄編號、新的照片編號,視為剛新增),原本的寶寶與紀錄都不動。
  /// 回傳新寶寶,以及每張照片的(舊照片編號, 新照片編號, 新紀錄編號),照片檔由呼叫端複製。
  /// 同步來的資料可能一天超過 10 筆,複製時不檢查每日上限(比照同步與匯入)。
  Future<(Baby, List<(String, String, String)>)> copyBaby(int fromSeq, String rawName) => db.transaction(() async {
        final baby = await addBaby(rawName);
        final rows = await _live(fromSeq).get();
        final now = _now();
        final photos = <(String, String, String)>[];
        for (final r in rows) {
          final id = newId();
          final newPhotos = <String>[];
          for (final ph in r.photoIds.isEmpty ? const <String>[] : r.photoIds.split(',')) {
            final np = newId();
            newPhotos.add(np);
            photos.add((ph, np, id));
          }
          await db.into(db.records).insert(r.copyWith(
              id: id,
              babySeq: baby.seq,
              photoIds: newPhotos.join(','),
              createdAt: now,
              updatedAt: now,
              dirty: true,
              cloudUpdatedAt: const Value(null)));
        }
        return (baby, photos);
      });

  /// 刪除寶寶:紀錄與照片一併刪除(呼叫端負責先刪雲端的資料與照片檔)。寶寶留一筆刪除標記,
  /// 有開同步時讓其他手機也知道。
  Future<List<String>> deleteBabyLocal(int seq) => db.transaction(() async {
        final photoIds = <String>[];
        final rows = await (db.select(db.records)..where((r) => r.babySeq.equals(seq))).get();
        for (final r in rows) {
          if (r.photoIds.isNotEmpty) photoIds.addAll(r.photoIds.split(','));
        }
        await (db.delete(db.records)..where((r) => r.babySeq.equals(seq))).go();
        await (db.delete(db.photos)..where((p) => p.id.isIn(photoIds))).go();
        await (db.update(db.babies)..where((b) => b.seq.equals(seq)))
            .write(BabiesCompanion(deleted: const Value(true), updatedAt: Value(_now()), dirty: const Value(true)));
        if (await getSetting(Keys.currentBaby) == '$seq') await setSetting(Keys.currentBaby, null);
        return photoIds;
      });

  // ── 紀錄 ────────────────────────────────────────────────

  SimpleSelectStatement<$RecordsTable, RecordRow> _live(int babySeq) =>
      db.select(db.records)..where((r) => r.babySeq.equals(babySeq) & r.deleted.equals(false));

  Stream<List<FeedRecord>> watchAll(int babySeq) =>
      (_live(babySeq)..orderBy([(r) => OrderingTerm.asc(r.timeUtc)])).watch().map((rows) => rows.map(recordFromRow).toList());

  Stream<List<FeedRecord>> watchMonth(int babySeq, int year, int month) {
    final prefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-';
    return (_live(babySeq)
          ..where((r) => r.localDay.like('$prefix%'))
          ..orderBy([(r) => OrderingTerm.asc(r.timeUtc)]))
        .watch()
        .map((rows) => rows.map(recordFromRow).toList());
  }

  Stream<List<FeedRecord>> watchDay(int babySeq, Day day) => (_live(babySeq)
        ..where((r) => r.localDay.equals('$day'))
        ..orderBy([(r) => OrderingTerm.asc(r.timeUtc)]))
      .watch()
      .map((rows) => rows.map(recordFromRow).toList());

  Future<FeedRecord?> record(String id) async {
    final row = await (db.select(db.records)..where((r) => r.id.equals(id) & r.deleted.equals(false))).getSingleOrNull();
    return row == null ? null : recordFromRow(row);
  }

  Future<int> countOnDay(int babySeq, Day day, {String? exceptId}) async {
    final rows = await (_live(babySeq)..where((r) => r.localDay.equals('$day'))).get();
    return rows.where((r) => r.id != exceptId).length;
  }

  /// 新增或修改一筆紀錄。檢查:分組/食材必選(畫面先擋)、目標日期已滿 10 筆就報錯。
  Future<void> saveRecord(FeedRecord r, {required bool isNew}) async {
    if (await countOnDay(r.babySeq, r.day, exceptId: isNew ? null : r.id) >= Limits.recordsPerDay) {
      throw const InputProblem('這一天已經有 ${Limits.recordsPerDay} 筆紀錄了');
    }
    if (charCount(r.note) > Limits.noteMaxChars) {
      throw const InputProblem('備註最多 ${Limits.noteMaxChars} 個字');
    }
    final now = _now();
    final companion = RecordsCompanion(
      id: Value(r.id),
      babySeq: Value(r.babySeq),
      timeUtc: Value(r.timeUtcMs),
      tzOffset: Value(r.tzOffsetMinutes),
      localDay: Value('${r.day}'),
      foodId: Value(r.foodId),
      preparedCenti: Value(r.preparedCenti),
      preparedUnitId: Value(r.preparedUnitId),
      eatenCenti: Value(r.eatenCenti),
      eatenUnitId: Value(r.eatenUnitId),
      allergy: Value(r.allergy?.code),
      reaction: Value(r.reaction?.code),
      digestive: Value(r.digestive?.code),
      note: Value(r.note),
      photoIds: Value(r.photoIds.join(',')),
      updatedAt: Value(now),
      dirty: const Value(true),
    );
    if (isNew) {
      await db.into(db.records).insert(companion.copyWith(createdAt: Value(now)));
    } else {
      await (db.update(db.records)..where((x) => x.id.equals(r.id))).write(companion);
    }
  }

  /// 刪除用標記(避免同步後「復活」),照片另外處理。
  Future<void> deleteRecord(String id) => (db.update(db.records)..where((r) => r.id.equals(id))).write(
      RecordsCompanion(deleted: const Value(true), updatedAt: Value(_now()), dirty: const Value(true), photoIds: const Value('')));

  // ── 統計用的數量 ────────────────────────────────────────

  Future<Map<String, int>> counts() async {
    final babiesCount = (await babies()).length;
    final records = await (db.select(db.records)..where((r) => r.deleted.equals(false))).get();
    final photos = await db.select(db.photos).get();
    return {
      'babies': babiesCount,
      'records': records.length,
      'photos': photos.where((p) => !p.deleteFromCloud).length,
      'pending_records': records.where((r) => r.dirty).length,
      'pending_photos': photos.where((p) => p.hasLocal && p.cloudFileId == null).length,
    };
  }
}
