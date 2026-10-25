import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/data/database.dart';
import 'package:mama_fufood/data/store.dart';
import 'package:mama_fufood/services/photo_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'fake_cloud.dart';

class _TempPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _TempPaths(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => '$root/support';

  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mff_photo_');
    PathProviderPlatform.instance = _TempPaths(root.path);
  });

  tearDown(() => root.delete(recursive: true));

  test('只在雲端的照片下載卡住時，不會一直等（超過時間就當作拿不到，下次再試）', () async {
    final store = Store(AppDb(NativeDatabase.memory()));
    addTearDown(store.db.close);
    final cloud = FakeCloud();
    final photos = PhotoService(store,
        cloud: () => cloud, cloudEnabled: () async => true, loadTimeout: const Duration(milliseconds: 300));
    final uploaded = await cloud.upload('folder', 'p1.jpg', Stream.value([1, 2, 3]), 3, 'image/jpeg');
    await store.db.into(store.db.photos).insert(PhotosCompanion.insert(
        id: 'p1', recordId: 'r1', createdAt: 0, hasLocal: const Value(false), cloudFileId: Value(uploaded.id)));

    cloud.hangDownloads = true;
    final watch = Stopwatch()..start();
    expect(await photos.resolve('p1'), isNull);
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));

    // 網路恢復之後再要一次就拿得到。
    cloud.hangDownloads = false;
    final file = await photos.resolve('p1');
    expect(await file!.readAsBytes(), [1, 2, 3]);
  });

  test('已經存在手機上的照片拿得到（之前會一直等不到結果）', () async {
    final store = Store(AppDb(NativeDatabase.memory()));
    addTearDown(store.db.close);
    final photos = PhotoService(store, cloud: () => null, cloudEnabled: () async => false);
    await photos.importPhoto('p2', 'r1', [9, 8, 7]);
    final file = await photos.resolve('p2').timeout(const Duration(seconds: 5));
    expect(await file!.readAsBytes(), [9, 8, 7]);
    // 同一張再要一次也沒問題(上一次的清理有確實完成)。
    expect(await photos.resolve('p2').timeout(const Duration(seconds: 5)), isNotNull);
  });
}
