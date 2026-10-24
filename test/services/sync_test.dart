import 'package:drift/drift.dart' show driftRuntimeOptions;
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

  test('一支手機:上傳、確認後清掉暫存;再同步不重傳', () async {
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

  test('第二支手機:第一次同步把雲端的寶寶與紀錄拉下來', () async {
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

  test('沒有衝突的修改自動合併;同一筆兩邊都改 → 交給使用者選(每筆保留較新的)', () async {
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
    expect(a.asked + b.asked, 0, reason: '改的是不同筆,沒有衝突');

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
    await b.edit(r.id, '手機的(比較新)');
    b.answer = ConflictChoice.cloudWins;
    await b.sync.syncNow(reason: 'test');
    expect((await b.all(baby.seq)).single.note, '雲端的');
  });

  test('刪除用標記,同步後不會「復活」', () async {
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

  test('斷網時同步失敗,手機上的資料一筆都不少,恢復後補上傳', () async {
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

  test('雲端的檔案不見了(例如刪了 App 的隱藏資料):不刪手機上的,重新傳上去', () async {
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

  test('兩支手機離線時各自新增寶寶撞號:後到的自動改用下一個沒用過的序號', () async {
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

  test('多筆衝突選「關閉雲端同步記錄」:關掉開關,手機上的資料不動', () async {
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
}
