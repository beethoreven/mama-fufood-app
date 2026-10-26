import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/core/text.dart';
import 'package:mama_fufood/core/time.dart';
import 'package:mama_fufood/data/database.dart';
import 'package:mama_fufood/data/store.dart';
import 'package:mama_fufood/domain/record.dart';
import 'package:mama_fufood/services/sync_engine.dart';

import 'fake_cloud.dart';

/// 一支手機:自己的本機資料庫 + 同一個(假的)雲端硬碟。
class Phone {
  Phone(this.cloud) : store = Store(AppDb(NativeDatabase.memory())) {
    sync = SyncEngine(store: store, cloud: () => cloud, enabled: () async => await store.getSetting(Keys.syncRecords) == '1');
  }

  final FakeCloud cloud;
  final Store store;
  late final SyncEngine sync;
  ConflictChoice answer = ConflictChoice.keepNewer;
  int asked = 0;

  Future<void> enable() async {
    sync.resolver = (conflicts) async {
      asked = conflicts.length;
      return answer;
    };
    await sync.startFresh('account-1');
    await store.setSetting(Keys.syncRecords, '1');
  }

  Future<FeedRecord> add(int babySeq, {int food = 1, String note = '', Day day = const Day(2026, 10, 23)}) async {
    final r = FeedRecord(
      id: newId(),
      babySeq: babySeq,
      timeUtcMs: TimeRules.toUtcMs(day, 9, 0, 480),
      tzOffsetMinutes: 480,
      foodId: food,
      preparedCenti: 3000,
      preparedUnitId: 1,
      eatenCenti: 2550,
      eatenUnitId: 1,
      allergy: Allergy.none,
      reaction: Reaction.like,
      note: note,
      photoIds: const [],
      createdAtMs: 0,
      updatedAtMs: 0,
    );
    await store.saveRecord(r, isNew: true);
    return (await store.record(r.id))!;
  }

  Future<void> edit(String id, String note) async {
    final r = (await store.record(id))!;
    await store.saveRecord(
        FeedRecord(
          id: r.id, babySeq: r.babySeq, timeUtcMs: r.timeUtcMs, tzOffsetMinutes: r.tzOffsetMinutes, foodId: r.foodId,
          preparedCenti: r.preparedCenti, preparedUnitId: r.preparedUnitId, eatenCenti: r.eatenCenti,
          eatenUnitId: r.eatenUnitId, allergy: r.allergy, reaction: r.reaction, note: note, photoIds: r.photoIds,
          createdAtMs: r.createdAtMs, updatedAtMs: r.updatedAtMs,
        ),
        isNew: false);
  }

  Future<List<FeedRecord>> all(int seq) => store.watchAll(seq).first;

  /// 模擬匯入:同樣的紀錄(編號、內容、建立時間都一樣),標成剛修改、還沒同步。
  Future<void> importFrom(Phone other, int fromSeq, int toSeq) async {
    final rows = await (other.store.db.select(other.store.db.records)..where((r) => r.babySeq.equals(fromSeq))).get();
    for (final r in rows) {
      await store.db.into(store.db.records).insert(r.copyWith(
          babySeq: toSeq, updatedAt: TimeRules.now().millisecondsSinceEpoch, dirty: true, cloudUpdatedAt: const Value(null)));
    }
  }

  Future<List<String>> babyList() async => [for (final b in await store.babies()) '${b.seq}:${b.name}'];

  Future<int> dirty() async => (await (store.db.select(store.db.records)..where((r) => r.dirty.equals(true))).get()).length;
}

void main() {
  // 每支假手機各有一個記憶體資料庫,是刻意的。
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  var clock = DateTime.utc(2026, 10, 23, 1);
  setUp(() {
    clock = DateTime.utc(2026, 10, 23, 1);
    TimeRules.now = () => clock = clock.add(const Duration(seconds: 1));
  });

  test('一支手機：上傳、確認後清掉暫存；再同步不重傳', () async {
    final cloud = FakeCloud();
    final a = Phone(cloud);
    await a.enable();
    final baby = await a.store.addBaby('小寶');
    await a.add(baby.seq);
    await a.add(baby.seq, food: 2);
    await a.sync.syncNow(reason: 'test');
    expect(a.sync.state, SyncState.ok);
    expect(await a.dirty(), 0);
    expect(cloud.files.values.where((f) => f.name.startsWith(CloudNames.recordPrefix)).length, 2);
    final writes = cloud.files.length;
    await a.sync.syncNow(reason: 'again');
    expect(cloud.files.length, writes);
  });

  test('第二支手機：第一次同步把雲端的寶寶與紀錄拉下來', () async {
    final cloud = FakeCloud();
    final a = Phone(cloud);
    await a.enable();
    final baby = await a.store.addBaby('小寶');
    await a.add(baby.seq, note: '第一口');
    await a.sync.syncNow(reason: 'test');

    final b = Phone(cloud);
    await b.enable();
    await b.sync.syncNow(reason: 'test');
    final babies = await b.store.babies();
    expect(babies.map((x) => x.name), ['小寶']);
    final records = await b.all(babies.first.seq);
    expect(records.single.note, '第一口');
    expect(records.single.eatenCenti, 2550);
    expect(b.asked, 0);
  });

  test('沒有衝突的修改自動合併；同一筆兩邊都改 → 交給使用者選（每筆保留較新的）', () async {
    final cloud = FakeCloud();
    final a = Phone(cloud), b = Phone(cloud);
    await a.enable();
    final baby = await a.store.addBaby('小寶');
    final r1 = await a.add(baby.seq);
    final r2 = await a.add(baby.seq, food: 2);
    await a.sync.syncNow(reason: 'test');
    await b.enable();
    await b.sync.syncNow(reason: 'test');

    await a.edit(r1.id, 'A 改了第一筆');
    await b.edit(r2.id, 'B 改了第二筆');
    await a.sync.syncNow(reason: 'test');
    await b.sync.syncNow(reason: 'test');
    await a.sync.syncNow(reason: 'test');
    for (final p in [a, b]) {
      final notes = {for (final r in await p.all(baby.seq)) r.id: r.note};
      expect(notes[r1.id], 'A 改了第一筆');
      expect(notes[r2.id], 'B 改了第二筆');
    }
    expect(a.asked + b.asked, 0, reason: '改的是不同筆，沒有衝突');

    await a.edit(r1.id, 'A 先改');
    await b.edit(r1.id, 'B 後改');
    await a.sync.syncNow(reason: 'test');
    await b.sync.syncNow(reason: 'test');
    expect(b.asked, 1);
    expect((await b.all(baby.seq)).firstWhere((r) => r.id == r1.id).note, 'B 後改', reason: 'B 的比較新');
    await a.sync.syncNow(reason: 'test');
    expect((await a.all(baby.seq)).firstWhere((r) => r.id == r1.id).note, 'B 後改');
  });

  test('衝突時選「以雲端覆蓋本機」', () async {
    final cloud = FakeCloud();
    final a = Phone(cloud), b = Phone(cloud);
    await a.enable();
    final baby = await a.store.addBaby('小寶');
    final r = await a.add(baby.seq);
    await a.sync.syncNow(reason: 'test');
    await b.enable();
    await b.sync.syncNow(reason: 'test');
    await a.edit(r.id, '雲端的');
    await a.sync.syncNow(reason: 'test');
    await b.edit(r.id, '手機的（比較新）');
    b.answer = ConflictChoice.cloudWins;
    await b.sync.syncNow(reason: 'test');
    expect((await b.all(baby.seq)).single.note, '雲端的');
  });

  test('刪除用標記，同步後不會「復活」', () async {
    final cloud = FakeCloud();
    final a = Phone(cloud), b = Phone(cloud);
    await a.enable();
    final baby = await a.store.addBaby('小寶');
    final r = await a.add(baby.seq);
    await a.sync.syncNow(reason: 'test');
    await b.enable();
    await b.sync.syncNow(reason: 'test');
    await a.store.deleteRecord(r.id);
    await a.sync.syncNow(reason: 'test');
    await b.sync.syncNow(reason: 'test');
    expect(await b.all(baby.seq), isEmpty);
    await b.sync.syncNow(reason: 'test');
    await a.sync.syncNow(reason: 'test');
    expect(await a.all(baby.seq), isEmpty);
  });

  test('斷網時同步失敗，手機上的資料一筆都不少，恢復後補上傳', () async {
    final cloud = FakeCloud();
    final a = Phone(cloud);
    await a.enable();
    final baby = await a.store.addBaby('小寶');
    await a.add(baby.seq);
    cloud.offline = true;
    await a.sync.syncNow(reason: 'test');
    expect(a.sync.state, SyncState.failed);
    expect((await a.all(baby.seq)).length, 1);
    expect(await a.dirty(), 1);
    cloud.offline = false;
    await a.sync.syncNow(reason: 'test');
    expect(a.sync.state, SyncState.ok);
    expect(await a.dirty(), 0);
  });

  test('雲端的檔案不見了（例如刪了 App 的隱藏資料）：不刪手機上的，重新傳上去', () async {
    final cloud = FakeCloud();
    final a = Phone(cloud);
    await a.enable();
    final baby = await a.store.addBaby('小寶');
    await a.add(baby.seq);
    await a.sync.syncNow(reason: 'test');
    cloud.files.clear();
    await a.sync.syncNow(reason: 'test');
    expect((await a.all(baby.seq)).length, 1);
    expect(cloud.files.values.where((f) => f.name.startsWith(CloudNames.recordPrefix)).length, 1);
  });

  test('兩支手機離線時各自新增寶寶撞號：後到的自動改用下一個沒用過的序號', () async {
    final cloud = FakeCloud();
    final a = Phone(cloud), b = Phone(cloud);
    await a.enable();
    await b.enable();
    final ba = await a.store.addBaby('大寶');
    clock = clock.add(const Duration(minutes: 1));
    final bb = await b.store.addBaby('二寶');
    expect(ba.seq, bb.seq, reason: '兩邊都是序號 1');
    await b.add(bb.seq, note: '二寶的紀錄');
    await a.sync.syncNow(reason: 'test');
    await b.sync.syncNow(reason: 'test');
    final babiesB = await b.store.babies();
    expect(babiesB.map((x) => '${x.seq}:${x.name}'), ['1:大寶', '2:二寶']);
    expect((await b.all(2)).single.note, '二寶的紀錄');
    await a.sync.syncNow(reason: 'test');
    expect((await a.store.babies()).map((x) => '${x.seq}:${x.name}'), ['1:大寶', '2:二寶']);
    expect((await a.all(2)).single.note, '二寶的紀錄');
  });

  test('多筆衝突選「關閉雲端同步記錄」：關掉開關，手機上的資料不動', () async {
    final cloud = FakeCloud();
    final a = Phone(cloud), b = Phone(cloud);
    await a.enable();
    final baby = await a.store.addBaby('小寶');
    final r1 = await a.add(baby.seq);
    final r2 = await a.add(baby.seq, food: 2);
    await a.sync.syncNow(reason: 'test');
    await b.enable();
    await b.sync.syncNow(reason: 'test');
    await a.edit(r1.id, 'a1');
    await a.edit(r2.id, 'a2');
    await a.sync.syncNow(reason: 'test');
    await b.edit(r1.id, 'b1');
    await b.edit(r2.id, 'b2');
    b.answer = ConflictChoice.stopSync;
    await b.sync.syncNow(reason: 'test');
    expect(b.asked, 2);
    expect(await b.store.getSetting(Keys.syncRecords), '0');
    expect({for (final r in await b.all(baby.seq)) r.note}, {'b1', 'b2'});
  });

  test('重裝後先新增同名寶寶、匯入、再打開同步：認成同一個寶寶，不出現「(2)」，也不算衝突', () async {
    final cloud = FakeCloud();
    final a = Phone(cloud);
    await a.enable();
    final baby = await a.store.addBaby('小明');
    await a.add(baby.seq, note: '第一口');
    await a.add(baby.seq, food: 2, day: const Day(2026, 10, 24));
    await a.sync.syncNow(reason: 'test');

    clock = clock.add(const Duration(days: 1));
    final b = Phone(cloud);
    final mine = await b.store.addBaby('小明');
    await b.importFrom(a, baby.seq, mine.seq);
    await b.enable();
    await b.sync.syncNow(reason: 'test');
    expect(b.sync.state, SyncState.ok);
    expect(await b.babyList(), ['1:小明']);
    expect((await b.all(1)).map((r) => r.note), containsAll(['第一口']));
    expect((await b.all(1)).length, 2);
    expect(b.asked, 0, reason: '內容一樣，只是修改時間不同，不算衝突');
    expect(await b.dirty(), 0);
  });

  test('名字對上、序號不同：手機上的改用雲端的序號；占著那個序號的寶寶換到新序號', () async {
    final cloud = FakeCloud();
    final a = Phone(cloud);
    await a.enable();
    final baby = await a.store.addBaby('小明');
    await a.add(baby.seq, note: '小明的');
    await a.sync.syncNow(reason: 'test');

    final b = Phone(cloud);
    final big = await b.store.addBaby('大寶');
    await b.add(big.seq, note: '大寶的');
    final ming = await b.store.addBaby('小明');
    await b.importFrom(a, baby.seq, ming.seq);
    await b.enable();
    await b.sync.syncNow(reason: 'test');
    expect(await b.babyList(), ['1:小明', '3:大寶']);
    expect((await b.all(1)).single.note, '小明的');
    expect((await b.all(3)).single.note, '大寶的');
    expect(b.asked, 0);

    await a.sync.syncNow(reason: 'test');
    expect(await a.babyList(), ['1:小明', '3:大寶']);
    expect((await a.all(3)).single.note, '大寶的');
  });

  test('同一筆紀錄內容真的不同才是衝突', () async {
    final cloud = FakeCloud();
    final a = Phone(cloud);
    await a.enable();
    final baby = await a.store.addBaby('小明');
    final r = await a.add(baby.seq, note: '雲端的');
    await a.sync.syncNow(reason: 'test');

    final b = Phone(cloud);
    final mine = await b.store.addBaby('小明');
    await b.importFrom(a, baby.seq, mine.seq);
    await b.edit(r.id, '手機上改過');
    await b.enable();
    await b.sync.syncNow(reason: 'test');
    expect(b.asked, 1);
  });

  test('預期外的狀況（雲端有兩個同名的寶寶）：不自動改名，交給畫面說明、不重試', () async {
    final cloud = FakeCloud();
    final a = Phone(cloud), b = Phone(cloud);
    await a.enable();
    await a.store.addBaby('小明');
    await a.sync.syncNow(reason: 'test');
    // 舊版 App 留下的狀況:手動把雲端清單改成兩個同名的寶寶。
    final file = cloud.files.values.firstWhere((f) => f.name == CloudNames.babies);
    final now = TimeRules.now().millisecondsSinceEpoch;
    file.bytes = utf8.encode('{"babies":[{"seq":1,"name":"小明","created_at":1,"updated_at":$now,"deleted":false},'
            '{"seq":2,"name":"小明","created_at":2,"updated_at":$now,"deleted":false}]}');
    MergeProblem? reported;
    b.sync.onMergeProblem = (p) async => reported = p;
    await b.enable();
    await b.sync.syncNow(reason: 'test');
    expect(b.sync.state, SyncState.failed);
    expect(reported?.code, 'cloud_duplicate_names');
    expect(await b.babyList(), isEmpty);
  });

  test('有開同步時改名：另外建立新名字的寶寶並複製紀錄，原本的寶寶與紀錄都不動，另一支手機兩個都有', () async {
    final cloud = FakeCloud();
    final a = Phone(cloud), b = Phone(cloud);
    await a.enable();
    final ming = await a.store.addBaby('小明');
    final r = await a.add(ming.seq, note: '原本的');
    await a.sync.syncNow(reason: 'test');
    await b.enable();
    await b.sync.syncNow(reason: 'test');

    final (copy, photos) = await a.store.copyBaby(ming.seq, '明明');
    expect(photos, isEmpty);
    await a.sync.syncNow(reason: 'test');
    await b.sync.syncNow(reason: 'test');
    for (final p in [a, b]) {
      expect(await p.babyList(), ['1:小明', '2:明明']);
      expect((await p.all(1)).single.id, r.id);
      final copied = (await p.all(copy.seq)).single;
      expect(copied.note, '原本的');
      expect(copied.id, isNot(r.id));
    }
    expect(a.asked + b.asked, 0);
  });
}
