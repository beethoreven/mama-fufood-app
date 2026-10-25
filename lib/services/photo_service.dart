import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/log.dart';
import '../core/text.dart';
import '../data/database.dart';
import '../data/store.dart';
import 'drive_store.dart';

/// 編輯中的照片:已經存在的(只有編號),或剛選的(暫存檔,還沒存進紀錄)。
class DraftPhoto {
  DraftPhoto.existing(this.id) : file = null;

  DraftPhoto.fresh(this.id, File this.file);

  final String id;
  final File? file;

  bool get isNew => file != null;
}

/// 照片(SPEC 第 4、13 節):
/// - 一律重新壓縮成 JPEG:長邊 1280 像素、品質 80;先依方向資訊轉正,再移除拍攝地點等
///   所有附帶資訊。
/// - 存在 files/photos/(不在 Android 自動備份的範圍)。
/// - 「照片存到雲端」開著時上傳到使用者看得到的「媽媽記副食品/照片」資料夾;
///   上傳並確認成功(核對 MD5)後才刪本機照片;斷網只影響照片讀取。
/// - 關掉開關只停止上傳新照片,已經在雲端的照片照常顯示。
class PhotoService {
  PhotoService(this.store, {required this.cloud, required this.cloudEnabled, this.loadTimeout = PhotoSpec.loadTimeout});

  final Store store;

  /// 顯示一張照片最多等多久(見 PhotoSpec.loadTimeout;測試會改短)。
  final Duration loadTimeout;

  /// 需要時才建立(要登入、要有雲端硬碟權限)。
  final CloudStore? Function() cloud;
  final Future<bool> Function() cloudEnabled;

  static const folderPath = ['媽媽記副食品', '照片'];

  AppDb get _db => store.db;

  Future<Directory> _dir(String name, {bool cache = false}) async {
    final base = cache ? await getTemporaryDirectory() : await getApplicationSupportDirectory();
    final d = Directory(p.join(base.path, name));
    await d.create(recursive: true);
    return d;
  }

  Future<File> _localFile(String id) async => File(p.join((await _dir('photos')).path, '$id.jpg'));

  /// 從相簿選照片(系統的照片挑選器,不要求讀取整個相簿的權限),壓縮成暫存檔。
  Future<List<DraftPhoto>> pick(int max) async {
    if (max <= 0) return const [];
    final picked = await ImagePicker().pickMultiImage(limit: max >= 2 ? max : null, requestFullMetadata: false);
    final out = <DraftPhoto>[];
    for (final x in picked.take(max)) {
      out.add(await _compress(x.path));
    }
    AppLog.info('photo.picked', {'n': out.length});
    return out;
  }

  Future<DraftPhoto> _compress(String source) async {
    final id = newId();
    final target = p.join((await _dir('photo_draft', cache: true)).path, '$id.jpg');
    // 長邊縮到 1280:外掛的縮放規則是「短邊比例與長邊比例取小的」,所以長邊那一側給 1280、
    // 另一側給 1,縮放就由長邊決定。寬高要用沒有轉正之前的(外掛先縮放、後轉正)。
    final buffer = await ui.ImmutableBuffer.fromFilePath(source);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final w = descriptor.width, h = descriptor.height;
    descriptor.dispose();
    buffer.dispose();
    final long = w > h ? w : h;
    var sample = 1;
    while (long ~/ (sample * 2) >= PhotoSpec.longEdge) {
      sample *= 2;
    }
    final result = await FlutterImageCompress.compressAndGetFile(
      source,
      target,
      minWidth: w >= h ? PhotoSpec.longEdge : 1,
      minHeight: w >= h ? 1 : PhotoSpec.longEdge,
      quality: PhotoSpec.quality,
      inSampleSize: sample,
      autoCorrectionAngle: true,
      keepExif: false,
      format: CompressFormat.jpeg,
    );
    if (result == null) throw StateError('照片壓縮失敗');
    return DraftPhoto.fresh(id, File(result.path));
  }

  /// 儲存紀錄的第一步(在儲存紀錄的同一個交易裡呼叫):新照片**複製**進 photos/ 並登記。
  /// 暫存檔與拿掉的照片要等交易成功後才處理(afterCommit),交易失敗時什麼都沒少,可以重試。
  Future<void> stageDraft({required String recordId, required List<DraftPhoto> photos}) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final ph in photos.where((x) => x.isNew)) {
      final dest = await _localFile(ph.id);
      await ph.file!.copy(dest.path);
      await _db.into(_db.photos).insertOnConflictUpdate(
          PhotosCompanion.insert(id: ph.id, recordId: recordId, createdAt: now, hasLocal: const Value(true)));
    }
  }

  /// 儲存紀錄成功之後:刪暫存檔、刪掉這次拿掉的照片、開始上傳新照片。
  Future<void> afterCommit({required List<DraftPhoto> photos, required List<String> previous}) async {
    await discardDraft(photos);
    final keep = {for (final ph in photos) ph.id};
    for (final id in previous.where((id) => !keep.contains(id))) {
      await remove(id);
    }
    if (photos.any((x) => x.isNew)) _kick();
  }

  Future<void> discardDraft(List<DraftPhoto> photos) async {
    for (final ph in photos.where((x) => x.isNew)) {
      if (await ph.file!.exists()) await ph.file!.delete();
    }
  }

  Future<void> onRecordDeleted(List<String> photoIds) async {
    for (final id in photoIds) {
      await remove(id);
    }
  }

  /// 刪一張照片:本機檔案馬上刪;雲端有一份的話標記「待刪」,登入時補刪。
  Future<void> remove(String id) async {
    final local = await _localFile(id);
    if (await local.exists()) await local.delete();
    final cached = File(p.join((await _dir('photo_cloud', cache: true)).path, '$id.jpg'));
    if (await cached.exists()) await cached.delete();
    final row = await (_db.select(_db.photos)..where((x) => x.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    if (row.cloudFileId != null) {
      await (_db.update(_db.photos)..where((x) => x.id.equals(id)))
          .write(const PhotosCompanion(deleteFromCloud: Value(true), hasLocal: Value(false)));
      _kick();
    } else {
      await (_db.delete(_db.photos)..where((x) => x.id.equals(id))).go();
    }
  }

  final Map<String, Future<File?>> _resolving = {};

  /// 拿到可以顯示的檔案:本機的、下載過的,或現在從雲端下載(沒網路回 null)。
  /// 同一張照片同時被要好幾次時共用同一個下載(兩個下載寫同一個暫存檔會互相覆蓋)。
  /// 等太久(網路卡住、授權沒有回應)就當作拿不到,畫面不會一直轉圈;下次再要時重新試。
  ///
  /// ★ whenComplete 的清理一定要寫成區塊、不回傳值:寫成 `() => _resolving.remove(id)` 的話,
  ///   remove 會回傳存在表裡的那個 Future——也就是 whenComplete 自己——whenComplete 會等它,
  ///   等於自己等自己,永遠不會完成(所有已存的照片因此一直轉圈)。
  Future<File?> resolve(String id) => _resolving.putIfAbsent(
      id,
      () => _resolve(id).timeout(loadTimeout, onTimeout: () {
            AppLog.warn('photo.resolve_timeout');
            return null;
          }).whenComplete(() {
            _resolving.remove(id);
          }));

  Future<File?> _resolve(String id) async {
    final local = await _localFile(id);
    if (await local.exists()) return local;
    final cached = File(p.join((await _dir('photo_cloud', cache: true)).path, '$id.jpg'));
    if (await cached.exists()) return cached;
    final store = cloud();
    if (store == null) return null;
    try {
      final row = await (_db.select(_db.photos)..where((x) => x.id.equals(id))).getSingleOrNull();
      var fileId = row?.cloudFileId;
      if (fileId == null) {
        // 另一支手機上傳的照片:用檔名在照片資料夾裡找。
        final folder = await store.folder(folderPath);
        fileId = (await store.findByName(folder, '$id.jpg'))?.id;
      }
      if (fileId == null) return null;
      final tmp = File('${cached.path}.part');
      await store.downloadToFile(fileId, tmp);
      await tmp.rename(cached.path);
      return cached;
    } catch (e) {
      AppLog.warn('photo.resolve_failed', {'type': e.runtimeType.toString()});
      return null;
    }
  }

  bool _running = false;

  void _kick() {
    processCloud();
  }

  /// 上傳待上傳的照片、刪掉待刪的雲端照片。失敗就留到下次,絕不先刪本機。
  Future<void> processCloud() async {
    if (_running) return;
    _running = true;
    try {
      final store = cloud();
      if (store == null) return;
      final pendingDeletes = await (_db.select(_db.photos)..where((x) => x.deleteFromCloud.equals(true))).get();
      for (final row in pendingDeletes) {
        await store.delete(row.cloudFileId!);
        await (_db.delete(_db.photos)..where((x) => x.id.equals(row.id))).go();
        AppLog.info('photo.cloud_deleted');
      }
      if (!await cloudEnabled()) return;
      final pendingUploads = await (_db.select(_db.photos)
            ..where((x) => x.hasLocal.equals(true) & x.cloudFileId.isNull() & x.deleteFromCloud.equals(false)))
          .get();
      if (pendingUploads.isEmpty) return;
      final folder = await store.folder(folderPath);
      for (final row in pendingUploads) {
        final file = await _localFile(row.id);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        final md5 = crypto.md5.convert(bytes).toString();
        final uploaded = await store.upload(folder, '${row.id}.jpg', Stream.value(bytes), bytes.length, 'image/jpeg');
        if (uploaded.md5 != null && uploaded.md5 != md5) {
          // 雲端那份和手機上的不一樣:刪掉重傳,手機上的保留。
          AppLog.warn('photo.md5_mismatch');
          await store.delete(uploaded.id);
          continue;
        }
        await (_db.update(_db.photos)..where((x) => x.id.equals(row.id)))
            .write(PhotosCompanion(cloudFileId: Value(uploaded.id), cloudMd5: Value(md5)));
        // 確認成功後才刪本機照片。
        await file.delete();
        await (_db.update(_db.photos)..where((x) => x.id.equals(row.id))).write(const PhotosCompanion(hasLocal: Value(false)));
        AppLog.info('photo.uploaded');
      }
    } catch (e) {
      AppLog.warn('photo.cloud_failed', {'type': e.runtimeType.toString()});
    } finally {
      _running = false;
    }
  }

  /// 匯出用:照片的位元組(本機或雲端);拿不到回 null。
  Future<List<int>?> bytesOf(String id) async {
    final f = await resolve(id);
    return f == null ? null : await f.readAsBytes();
  }

  /// 匯入用:把照片寫進 photos/ 並登記(視為剛新增,照片雲端開著時會再上傳)。
  Future<void> importPhoto(String id, String recordId, List<int> bytes) async {
    final f = await _localFile(id);
    await f.writeAsBytes(bytes, flush: true);
    await _db.into(_db.photos).insertOnConflictUpdate(PhotosCompanion.insert(
        id: id, recordId: recordId, createdAt: DateTime.now().toUtc().millisecondsSinceEpoch, hasLocal: const Value(true)));
  }

  /// 刪除寶寶時:這些照片在雲端的檔案(有的話)。
  Future<List<String>> cloudFileIds(List<String> photoIds) async {
    final rows = await (_db.select(_db.photos)..where((x) => x.id.isIn(photoIds))).get();
    return [for (final r in rows) if (r.cloudFileId != null) r.cloudFileId!];
  }

  /// 刪除寶寶時:本機的照片檔一起刪(資料庫那邊由 Store.deleteBabyLocal 處理)。
  Future<void> deleteLocalFiles(List<String> photoIds) async {
    for (final id in photoIds) {
      final f = await _localFile(id);
      if (await f.exists()) await f.delete();
    }
  }
}
