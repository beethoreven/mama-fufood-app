import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/log.dart';
import '../core/time.dart';
import '../data/store.dart';
import 'drive_store.dart';
import 'export_crypto.dart';
import 'export_format.dart';
import 'export_keys.dart';
import 'photo_service.dart';

class ExportProblem implements Exception {
  const ExportProblem(this.message);

  final String message;

  @override
  String toString() => message;
}

class ExportResult {
  const ExportResult({required this.fileName, required this.babies, required this.records, required this.photos});

  final String fileName;
  final int babies;
  final int records;
  final int photos;
}

/// 匯出(SPEC 第 4 節、EXPORT_FORMAT_DRAFT.md):
/// 一個檔包含這支手機上的全部寶寶;整份加密(包含照片);存到使用者自己的雲端硬碟
/// 「媽媽記副食品」資料夾。沒有任何紀錄也可以匯出(裡面有設定)。
class ExportService {
  ExportService({required this.store, required this.photos, required this.appVersion});

  final Store store;
  final PhotoService photos;
  final String Function() appVersion;

  static const folder = ['媽媽記副食品'];

  /// 檔名不放寶寶名稱(外流時會洩漏名字),時間用手機當地時間。
  static String fileName(DateTime local) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '媽媽記副食品_匯出_${local.year}${two(local.month)}${two(local.day)}_'
        '${two(local.hour)}${two(local.minute)}${two(local.second)}.mff';
  }

  /// 組出 data.json(不含已刪除的紀錄;不認得的食材或單位照樣匯出)。
  Future<Map<String, Object?>> buildData() async {
    final settings = await store.allSettings();
    final db = store.db;
    final babies = await (db.select(db.babies)
          ..where((b) => b.deleted.equals(false))
          ..orderBy([(b) => OrderingTerm.asc(b.seq)]))
        .get();
    final out = <Map<String, Object?>>[];
    for (final b in babies) {
      final rows = await (db.select(db.records)
            ..where((r) => r.babySeq.equals(b.seq) & r.deleted.equals(false))
            ..orderBy([(r) => OrderingTerm.asc(r.timeUtc)]))
          .get();
      out.add({
        'seq': b.seq,
        'name': b.name,
        'records': [for (final r in rows) ExportFormat.encodeRecord(recordFromRow(r), photosAsPaths: true)],
      });
    }
    return {
      'format_version': ExportFormat.version,
      'settings': {
        'week_start': settings[Keys.weekStart] == 'sunday' ? 'sunday' : 'monday',
        'theme': const ['light', 'system'].contains(settings[Keys.theme]) ? settings[Keys.theme] : 'dark',
      },
      'babies': out,
    };
  }

  Future<ExportResult> run(CloudStore cloud, {void Function(String step)? progress}) async {
    final tmp = Directory(p.join((await getTemporaryDirectory()).path, 'export_${DateTime.now().millisecondsSinceEpoch}'));
    await tmp.create(recursive: true);
    String? uploadedId;
    try {
      progress?.call('整理資料');
      final data = await buildData();
      final photoIds = [
        for (final b in data['babies'] as List)
          for (final r in (b as Map)['records'] as List)
            for (final path in (r as Map)['photos'] as List) RegExp(r'photos/(.+)\.jpg').firstMatch(path as String)!.group(1)!,
      ];
      final zipFile = File(p.join(tmp.path, 'data.zip'));
      final encoder = ZipFileEncoder()..create(zipFile.path);
      encoder.addArchiveFile(ArchiveFile.string('data.json', jsonEncode(data)));
      progress?.call('整理照片');
      for (final id in photoIds) {
        // 照片只在雲端時先下載;任何一張失敗,整份匯出失敗(備份要嘛完整、要嘛不做)。
        final bytes = await photos.bytesOf(id);
        if (bytes == null) {
          await encoder.close();
          throw const ExportProblem('有照片無法從雲端下載,這次沒有匯出。請確認網路後再試。');
        }
        final f = File(p.join(tmp.path, '$id.jpg'));
        await f.writeAsBytes(bytes);
        await encoder.addFile(f, 'photos/$id.jpg', ZipFileEncoder.store);
        await f.delete();
      }
      await encoder.close();

      progress?.call('加密');
      final key = await ExportKeys(cloud).getOrCreate();
      final header = MffHeader(
        formatVersion: ExportFormat.version,
        appVersion: appVersion(),
        exportedAt: TimeRules.isoMillis(DateTime.now().toUtc().millisecondsSinceEpoch),
        keyId: key.id,
        noncePrefix: base64.encode(MffCrypto.randomBytes(8)),
      );
      final mff = File(p.join(tmp.path, 'out.mff'));
      await MffCrypto.encryptFile(plain: zipFile, out: mff, header: header, key: key.bytes);

      progress?.call('上傳到雲端硬碟');
      final name = fileName(DateTime.now());
      final folderId = await cloud.folder(folder);
      final length = await mff.length();
      final uploaded = await cloud.upload(folderId, name, mff.openRead(), length, 'application/octet-stream');
      uploadedId = uploaded.id;

      // 匯出後立即驗證:重新讀回、逐段解密,核對紀錄筆數與每張照片都在。
      progress?.call('驗證');
      final back = File(p.join(tmp.path, 'back.mff'));
      await cloud.downloadToFile(uploaded.id, back);
      final backZip = File(p.join(tmp.path, 'back.zip'));
      await MffCrypto.decryptFile(mff: back, out: backZip, key: key.bytes);
      final archive = ZipDecoder().decodeStream(InputFileStream(backZip.path));
      final dataEntry = archive.findFile('data.json');
      if (dataEntry == null) throw const _VerifyFailed();
      final parsed = ExportFormat.parse((jsonDecode(utf8.decode(dataEntry.readBytes()!)) as Map).cast<String, Object?>());
      final records = parsed.babies.fold<int>(0, (n, b) => n + b.records.length);
      final expected = (data['babies'] as List).fold<int>(0, (n, b) => n + ((b as Map)['records'] as List).length);
      if (records != expected) throw const _VerifyFailed();
      for (final id in photoIds) {
        final entry = archive.findFile('photos/$id.jpg');
        if (entry == null || entry.size == 0) throw const _VerifyFailed();
      }
      await archive.clear();
      AppLog.info('export.ok', {'babies': parsed.babies.length, 'records': records, 'photos': photoIds.length});
      return ExportResult(fileName: name, babies: parsed.babies.length, records: records, photos: photoIds.length);
    } on _VerifyFailed {
      AppLog.warn('export.verify_failed');
      if (uploadedId != null) await cloud.delete(uploadedId);
      throw const ExportProblem('匯出沒有成功,請再試一次。(壞掉的檔案已刪除)');
    } on MffCorrupted {
      AppLog.warn('export.verify_failed');
      if (uploadedId != null) await cloud.delete(uploadedId);
      throw const ExportProblem('匯出沒有成功,請再試一次。(壞掉的檔案已刪除)');
    } on CloudError catch (e) {
      if (e.isStorageFull) throw const ExportProblem('你的 Google 雲端硬碟空間不足,這次沒有匯出。');
      throw ExportProblem(e.message);
    } finally {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    }
  }
}

class _VerifyFailed implements Exception {
  const _VerifyFailed();
}
