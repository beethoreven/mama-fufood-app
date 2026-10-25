import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/domain/record.dart';
import 'package:mama_fufood/services/services.dart';
import 'package:mama_fufood/ui/record/record_dialog.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'harness.dart';
import 'scenarios.dart';

class _TempPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _TempPaths(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => '$root/support';

  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

const _tinyPng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

/// 檢視紀錄時點開照片,不用先按「修改」也能直接刪掉。
void main() {
  setUpUiTests();
  late Directory root;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('mff_ui_photo_');
    PathProviderPlatform.instance = _TempPaths(root.path);
  });

  tearDown(() => root.deleteSync(recursive: true));

  testWidgets('檢視中點開照片，可以直接刪除', (tester) async {
    late Services services;
    late FeedRecord record;
    final s = Scenario('record_photo_delete', go: openRecord, shows: () => find.text('刪除'));

    // 檔案讀寫是真的非同步:讓它在真的時間裡跑完,再推進畫面。
    Future<void> settleIo() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await runScenario(tester, s, screens[1], 1.0, ignoreOverflow: true, seed: (sv) async {
      services = sv;
      final all = await sv.store.watchAll(1).first;
      final spinach = all.firstWhere((r) => r.note.contains('嘴巴周圍'));
      // 1×1 的 PNG(縮圖要真的解得開)。
      await sv.photos.importPhoto('p1', spinach.id, base64Decode(_tinyPng));
      await sv.store.saveRecord(
          FeedRecord(
            id: spinach.id,
            babySeq: spinach.babySeq,
            timeUtcMs: spinach.timeUtcMs,
            tzOffsetMinutes: spinach.tzOffsetMinutes,
            foodId: spinach.foodId,
            preparedCenti: spinach.preparedCenti,
            preparedUnitId: spinach.preparedUnitId,
            eatenCenti: spinach.eatenCenti,
            eatenUnitId: spinach.eatenUnitId,
            allergy: spinach.allergy,
            reaction: spinach.reaction,
            note: spinach.note,
            photoIds: const ['p1'],
            createdAtMs: spinach.createdAtMs,
            updatedAtMs: 0,
          ),
          isNew: false);
      record = spinach;
    }, check: () async {
      final thumb = find.descendant(of: find.byType(RecordDialog), matching: find.byType(PhotoThumb)).first;
      await tester.ensureVisible(thumb);
      await settleIo();
      await tester.tap(thumb);
      await settleIo();
      await tester.tap(find.text('刪除這張照片'));
      await settleIo();
      await tester.tap(find.text('刪除').last);
      await settleIo();

      final saved = (await tester.runAsync(() => services.store.record(record.id)))!;
      expect(saved.photoIds, isEmpty);
      expect(File('${root.path}/support/photos/p1.jpg').existsSync(), isFalse);
      await settleIo();
      expect(find.byType(RecordDialog), findsOneWidget, reason: '刪完照片還在檢視畫面');
      expect(find.descendant(of: find.byType(RecordDialog), matching: find.byType(PhotoThumb)), findsNothing,
          reason: '畫面上的照片也要跟著不見');
    });
  });
}
