import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/core/time.dart';
import 'package:mama_fufood/domain/record.dart';
import 'package:mama_fufood/services/sync_engine.dart';
import 'package:mama_fufood/ui/flows.dart';

FeedRecord _rec(int month, int day) => FeedRecord(
      id: '6f1c2a9e-3b4d-4e8f-9a1b-2c3d4e5f6a7b',
      babySeq: 1,
      timeUtcMs: TimeRules.toUtcMs(Day(2026, month, day), 9, 0, 480),
      tzOffsetMinutes: 480,
      foodId: 1,
      preparedCenti: 100,
      preparedUnitId: 1,
      eatenCenti: 100,
      eatenUnitId: 1,
      allergy: null,
      reaction: null,
      note: '',
      photoIds: const [],
      createdAtMs: 0,
      updatedAtMs: 0,
    );

SyncConflict _c(FeedRecord local, FeedRecord? remote) => SyncConflict(local: local, remote: remote, remoteUpdatedAt: 0);

/// 多筆衝突的對話框列出衝突的日期:從舊到新、不重複,兩邊的日期都算,最多 10 個。
void main() {
  test('從舊到新、不重複；雲端那份改了日期也列出來', () {
    final text = conflictDaysText([
      _c(_rec(10, 23), _rec(10, 23)),
      _c(_rec(10, 2), null),
      _c(_rec(10, 16), _rec(9, 30)),
    ]);
    expect(text, '2026/9/30、2026/10/2、2026/10/16、2026/10/23');
  });

  test('超過 10 天只列前 10 天，後面寫共幾天', () {
    final text = conflictDaysText([for (var d = 1; d <= 12; d++) _c(_rec(10, d), null)]);
    expect(text, startsWith('2026/10/1、'));
    expect(text, endsWith('2026/10/10 等共 12 天'));
  });
}
