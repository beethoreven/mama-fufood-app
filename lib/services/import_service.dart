import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/log.dart';
import '../core/time.dart';
import '../data/database.dart';
import '../data/store.dart';
import '../domain/record.dart';
import 'api_client.dart';
import 'drive_store.dart';
import 'export_crypto.dart';
import 'export_format.dart';
import 'export_keys.dart';
import 'photo_service.dart';

class ImportProblem implements Exception {
  const ImportProblem(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 同名寶寶的狀況。
class BabyMatch {
  BabyMatch({required this.file, required this.localSeq, required this.conflict});

  final ParsedBaby file;

  /// 手機上同名的寶寶(沒有的話 null:匯入時建立新寶寶)。
  final int? localSeq;

  /// 直接用匯入檔取代,會讓手機上的東西不見或被改掉。
  final bool conflict;
}

class ImportPlan {
  ImportPlan({required this.dir, required this.parsed, required this.matches, required this.header});

  final Directory dir;
  final ParsedExport parsed;
  final List<BabyMatch> matches;
  final MffHeader header;

  List<BabyMatch> get conflicts => matches.where((m) => m.conflict).toList();
}

class ImportSummary {
  const ImportSummary({required this.babies, required this.records, required this.skipped});

  final int babies;
  final int records;
  final int skipped;
}

/// 匯入(SPEC 第 4 節、EXPORT_FORMAT_DRAFT.md 第 7 節的檢查順序)。
/// 任何一步不通過,整份不匯入,並說明原因。
class ImportService {
  ImportService({required this.store, required this.photos, required this.api, required this.appVersion});

  final Store store;
  final PhotoService photos;
  final ApiClient api;
  final String Function() appVersion;

  static int _cmp(String a, String b) {
    List<int> parts(String v) => v.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    final x = parts(a), y = parts(b);
    for (var i = 0; i < 3; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }

  /// 第 1~2 步:不用登入就能檢查的部分。
  Future<MffHeader> checkFile(File file) async {
    final parsed = await MffCrypto.readHeader(file);
    if (parsed == null) throw const ImportProblem('這不是媽媽記副食品的匯出檔。');
    final header = parsed.$1;
    if (_cmp(header.appVersion, appVersion()) > 0) {
      throw const ImportProblem('這個檔案是用較新版本的 App 匯出的，請先更新 App 再匯入。');
    }
    if (header.cipher != MffCrypto.cipherName) throw const ImportProblem('檔案損壞或被修改過，無法匯入。');
    return header;
  }

  /// 第 3~7 步:找金鑰、解密、解壓縮、(必要時)轉換格式、檢查內容。
  Future<ImportPlan> prepare(File file, CloudStore cloud, {void Function(String step)? progress}) async {
    final header = await checkFile(file);
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'import_${DateTime.now().millisecondsSinceEpoch}'));
    await dir.create(recursive: true);
    try {
      progress?.call('讀取金鑰');
      ExportKey? key;
      try {
        key = await ExportKeys(cloud).find(header.keyId);
      } on CloudError catch (e) {
        throw ImportProblem(e.message);
      }
      if (key == null) throw const ImportProblem('請用匯出這個檔案時的 Google 帳號登入，才能匯入。');

      progress?.call('解密');
      final zip = File(p.join(dir.path, 'data.zip'));
      try {
        await MffCrypto.decryptFile(mff: file, out: zip, key: key.bytes);
      } on MffCorrupted {
        throw const ImportProblem('檔案損壞或被修改過，無法匯入。');
      }

      progress?.call('檢查內容');
      final archive = ZipDecoder().decodeStream(InputFileStream(zip.path));
      // 安全檢查:路徑不能跳出資料夾、不能有絕對路徑;只能有 data.json 與 photos/{UUID}.jpg;
      // 解開後的大小不能超過手機可用空間(這裡另外設一個保守的上限)。
      var total = 0;
      for (final entry in archive) {
        final name = entry.name;
        final ok = name == 'data.json' || RegExp(r'^photos/[0-9a-f\-]{36}\.jpg$').hasMatch(name);
        if (!entry.isFile || !ok || p.isAbsolute(name) || name.contains('..')) {
          throw const ImportProblem('檔案損壞或被修改過，無法匯入。');
        }
        total += entry.size;
      }
      if (total > 4 * 1024 * 1024 * 1024) throw const ImportProblem('檔案太大，無法匯入。');
      final dataEntry = archive.findFile('data.json');
      if (dataEntry == null) throw const ImportProblem('檔案損壞或被修改過，無法匯入。');
      var data = (jsonDecode(utf8.decode(dataEntry.readBytes()!)) as Map).cast<String, Object?>();

      // 第 6 步:格式版本比這支 App 舊 → 只把 data.json 送後端逐版轉換(需登入,每人每天 5 次)。
      final fv = data['format_version'];
      if (fv is! int) throw const ImportProblem('檔案損壞或被修改過，無法匯入。');
      if (fv > ExportFormat.version) throw const ImportProblem('這個檔案是用較新版本的 App 匯出的，請先更新 App 再匯入。');
      if (fv < ExportFormat.version) {
        progress?.call('轉換舊格式');
        try {
          final res = await api.convert(data);
          if ((res['missing'] as List? ?? const []).isNotEmpty) {
            // 目前沒有這種欄位;以後有了再做補資料的介面(SPEC 第 4 節)。
            throw const ImportProblem('這個檔案缺少新版需要的資料，請更新 App 後再試。');
          }
          data = (res['data'] as Map).cast<String, Object?>();
        } on ApiError catch (e) {
          throw ImportProblem(e.isDailyLimit ? '今天的格式轉換次數已經用完，請明天再試。' : e.message);
        }
      }

      // 第 7 步:型別、允許的值、寶寶名稱不重複、照片都在、寶寶總數不超過 8 個。
      final ParsedExport parsed;
      try {
        parsed = ExportFormat.parse(data);
      } on FormatException catch (e) {
        throw ImportProblem('檔案的內容不符合格式：${e.message}');
      }
      for (final id in parsed.photoIds) {
        if (archive.findFile('photos/$id.jpg') == null) throw const ImportProblem('檔案損壞或被修改過，無法匯入。');
      }
      final photoEntries = archive.where((e) => e.name.startsWith('photos/')).length;
      if (photoEntries != parsed.photoIds.length) throw const ImportProblem('檔案損壞或被修改過，無法匯入。');
      for (final id in parsed.photoIds) {
        final out = OutputFileStream(p.join(dir.path, '$id.jpg'));
        archive.findFile('photos/$id.jpg')!.writeContent(out);
        await out.close();
      }
      await archive.clear();
      await zip.delete();

      final matches = await _match(parsed);
      final localNames = {for (final b in await store.babies()) b.name};
      final newOnes = matches.where((m) => m.localSeq == null).length;
      if (localNames.length + newOnes > Limits.maxBabies) {
        throw const ImportProblem('匯入後寶寶會超過 ${Limits.maxBabies} 個，不能匯入。');
      }
      AppLog.info('import.prepared', {'babies': parsed.babies.length, 'conflicts': matches.where((m) => m.conflict).length});
      return ImportPlan(dir: dir, parsed: parsed, matches: matches, header: header);
    } catch (_) {
      if (await dir.exists()) await dir.delete(recursive: true);
      rethrow;
    }
  }

  /// 同名寶寶的「資料衝突」:① 手機上有、匯入檔裡沒有的紀錄,
  /// 或 ② 同一筆紀錄兩邊內容不同(包含手機上已經刪除、匯入檔裡還在的)。
  Future<List<BabyMatch>> _match(ParsedExport parsed) async {
    final db = store.db;
    final babies = await store.babies();
    final out = <BabyMatch>[];
    for (final fb in parsed.babies) {
      final local = babies.where((b) => b.name == fb.name).firstOrNull;
      if (local == null) {
        out.add(BabyMatch(file: fb, localSeq: null, conflict: false));
        continue;
      }
      final rows = await (db.select(db.records)..where((r) => r.babySeq.equals(local.seq))).get();
      final fileById = {for (final r in fb.records) r.id: r};
      var conflict = false;
      for (final row in rows) {
        final f = fileById[row.id];
        if (row.deleted) {
          if (f != null) conflict = true;
          continue;
        }
        if (f == null) {
          conflict = true;
        } else if (jsonEncode(ExportFormat.encodeRecord(recordFromRow(row), photosAsPaths: true)) !=
            jsonEncode(ExportFormat.encodeRecord(f, photosAsPaths: true))) {
          conflict = true;
        }
        if (conflict) break;
      }
      out.add(BabyMatch(file: fb, localSeq: local.seq, conflict: conflict));
    }
    return out;
  }

  /// 第 10 步:寫入資料、套用設定。replace[name] = true 表示那個同名寶寶要取代。
  /// 匯入的紀錄視為剛修改(之後開同步時會走第一次同步的流程)。
  Future<ImportSummary> apply(ImportPlan plan, Map<String, bool> replace) async {
    final db = store.db;
    final now = TimeRules.now().toUtc().millisecondsSinceEpoch;
    var babies = 0, records = 0, skipped = 0;
    final photoWrites = <(String, String)>[];
    final replacedPhotos = <String>[];
    await db.transaction(() async {
      for (final m in plan.matches) {
        int seq;
        if (m.localSeq == null) {
          seq = (await store.addBaby(m.file.name)).seq;
        } else {
          seq = m.localSeq!;
          if (m.conflict && replace[m.file.name] != true) {
            skipped++;
            continue;
          }
          if (m.conflict) {
            // 取代:不做整合,手機上這個寶寶的紀錄全部換成匯入檔的。
            final old = await (db.select(db.records)..where((r) => r.babySeq.equals(seq))).get();
            final oldPhotos = [for (final r in old) if (r.photoIds.isNotEmpty) ...r.photoIds.split(',')];
            await (db.update(db.records)..where((r) => r.babySeq.equals(seq)))
                .write(RecordsCompanion(deleted: const Value(true), dirty: const Value(true), updatedAt: Value(now), photoIds: const Value('')));
            replacedPhotos.addAll(oldPhotos);
          }
        }
        babies++;
        for (final r in m.file.records) {
          await db.into(db.records).insertOnConflictUpdate(_row(r, seq, now));
          for (final ph in r.photoIds) {
            photoWrites.add((ph, r.id));
          }
          records++;
        }
      }
      await store.setSetting(Keys.weekStart, plan.parsed.weekStart);
      await store.setSetting(Keys.theme, plan.parsed.theme);
    });
    // 交易成功之後才刪被取代的舊照片(交易失敗時,舊紀錄還用得到它們)。
    for (final id in replacedPhotos) {
      await photos.remove(id);
    }
    for (final (photoId, recordId) in photoWrites) {
      final f = File(p.join(plan.dir.path, '$photoId.jpg'));
      if (await f.exists()) await photos.importPhoto(photoId, recordId, await f.readAsBytes());
    }
    // 匯入後顯示序號最小的寶寶(序號 1 可能已經刪掉、不再使用)。
    final all = await store.babies();
    if (all.isNotEmpty) await store.setSetting(Keys.currentBaby, '${all.first.seq}');
    AppLog.info('import.done', {'babies': babies, 'records': records, 'skipped': skipped});
    return ImportSummary(babies: babies, records: records, skipped: skipped);
  }

  RecordsCompanion _row(FeedRecord r, int seq, int now) => RecordsCompanion.insert(
        id: r.id,
        babySeq: seq,
        timeUtc: r.timeUtcMs,
        tzOffset: r.tzOffsetMinutes,
        localDay: '${TimeRules.localDay(r.timeUtcMs, r.tzOffsetMinutes)}',
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
        updatedAt: now,
        deleted: const Value(false),
        dirty: const Value(true),
        cloudUpdatedAt: const Value(null),
      );

  Future<void> cleanup(ImportPlan plan) async {
    if (await plan.dir.exists()) await plan.dir.delete(recursive: true);
  }
}
