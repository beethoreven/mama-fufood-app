import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/data/database.dart';
import 'package:mama_fufood/data/store.dart';
import 'package:mama_fufood/domain/record.dart';

/// 資料庫第 1 版(App 0.x)升到第 2 版(App 1.0.0):舊紀錄保留,「腹瀉或嘔吐」是空的,之後可以寫入。
void main() {
  test('從第 1 版升級：舊紀錄都在，新欄位是空的', () async {
    final dir = Directory.systemTemp.createTempSync('mff_db_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/mff.sqlite');

    // 做出一個第 1 版的資料庫:先用現在的程式建好、放一筆紀錄,再拿掉新欄位、版本號改回 1。
    var db = AppDb(NativeDatabase(file));
    final store = Store(db);
    final baby = await store.addBaby('小寶');
    await store.saveRecord(
        FeedRecord(
          id: '6f1c2a9e-3b4d-4e8f-9a1b-2c3d4e5f6a7b',
          babySeq: baby.seq,
          timeUtcMs: DateTime.utc(2026, 10, 1, 1).millisecondsSinceEpoch,
          tzOffsetMinutes: 480,
          foodId: 1,
          preparedCenti: 3000,
          preparedUnitId: 1,
          eatenCenti: 2000,
          eatenUnitId: 1,
          allergy: Allergy.none,
          reaction: Reaction.like,
          note: '舊紀錄',
          photoIds: const [],
          createdAtMs: 0,
          updatedAtMs: 0,
        ),
        isNew: true);
    await db.customStatement('ALTER TABLE records DROP COLUMN digestive');
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();

    db = AppDb(NativeDatabase(file));
    addTearDown(db.close);
    final upgraded = Store(db);
    final r = await upgraded.record('6f1c2a9e-3b4d-4e8f-9a1b-2c3d4e5f6a7b');
    expect(r!.note, '舊紀錄');
    expect(r.reaction, Reaction.like);
    expect(r.digestive, isNull);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 2);

    await (db.update(db.records)..where((x) => x.id.equals(r.id)))
        .write(const RecordsCompanion(digestive: Value('diarrhea')));
    expect((await upgraded.record(r.id))!.digestive, Digestive.diarrhea);
  });
}
