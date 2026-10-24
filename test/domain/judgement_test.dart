import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/core/time.dart';
import 'package:mama_fufood/domain/judgement.dart';
import 'package:mama_fufood/domain/record.dart';

var _n = 0;

FeedRecord rec({Allergy? allergy, Reaction? reaction, Day? day}) {
  final d = day ?? const Day(2026, 10, 1);
  _n += 1;
  return FeedRecord(
    id: 'r$_n',
    babySeq: 1,
    timeUtcMs: TimeRules.toUtcMs(d, 12, _n % 60, 480),
    tzOffsetMinutes: 480,
    foodId: 1,
    preparedCenti: 0,
    preparedUnitId: 1,
    eatenCenti: 0,
    eatenUnitId: 1,
    allergy: allergy,
    reaction: reaction,
    note: '',
    photoIds: const [],
    createdAtMs: 0,
    updatedAtMs: 0,
  );
}

List<FeedRecord> allergies(List<Allergy?> values) => [for (final v in values) rec(allergy: v)];

void main() {
  const none = Allergy.none, next = Allergy.nextDay, same = Allergy.sameDay;

  group('過敏（SPEC 第 8 節、判斷邏輯說明頁的例子）', () {
    test('沒有、沒有 → 紀錄不足（不顯示圖示）', () {
      expect(judgeAllergy(allergies([none, none])), isNull);
    });
    test('沒有、沒有、沒有 → 穩定', () {
      expect(judgeAllergy(allergies([none, none, none])), AllergyLevel.stable);
    });
    test('沒有×3、隔天 → 平均 0.075，只有 1 次隔天 → 穩定', () {
      expect(judgeAllergy(allergies([none, none, none, next])), AllergyLevel.stable);
    });
    test('沒有、當天 → 平均 0.5，出現過當天 → 風險', () {
      expect(judgeAllergy(allergies([none, same])), AllergyLevel.risk);
    });
    test('沒有×3、當天×2 → 平均 0.4，但當天 2 次 → 過敏', () {
      expect(judgeAllergy(allergies([none, none, none, same, same])), AllergyLevel.allergic);
    });
    test('只出現過一次隔天也算足夠', () {
      expect(judgeAllergy(allergies([next])), AllergyLevel.risk);
    });
    test('隔天 2 次 → 至少風險', () {
      expect(judgeAllergy(allergies([none, none, none, none, none, none, none, none, next, next])),
          AllergyLevel.risk);
    });
    test('邊界：平均剛好 0.2 是穩定、剛好 0.7 是風險', () {
      // 0.2:10 筆裡 2 筆當天?不行,當天會觸發最低標示。用隔天湊:0.3×2/3 = 0.2。
      expect(judgeAllergy(allergies([next, next, none])), AllergyLevel.risk, reason: '隔天 2 次 → 至少風險');
      // 0.7 剛好:當天 7 + 沒有 3 → 當天 ≥2 直接過敏;改驗證 >0.7 才是過敏:全部當天。
      expect(judgeAllergy(allergies([same, same, same])), AllergyLevel.allergic);
    });
    test('未選的不納入運算', () {
      expect(judgeAllergy(allergies([none, none, null, null])), isNull);
      expect(judgeAllergy(allergies([none, none, none, null])), AllergyLevel.stable);
    });
  });

  group('喜好', () {
    final today = const Day(2026, 10, 23);

    List<FeedRecord> reactions(Map<Reaction, int> counts, {Day? day}) => [
          for (final e in counts.entries)
            for (var i = 0; i < e.value; i++) rec(reaction: e.key, day: day ?? const Day(2026, 10, 1)),
        ];

    test('喜歡 6、接受 3、排斥 1 → 平均 0.5 → 喜歡', () {
      expect(judgePreference(reactions({Reaction.like: 6, Reaction.accept: 3, Reaction.reject: 1}), today: today),
          PreferenceLevel.like);
    });
    test('排斥 2、接受 1 → -0.67 → 排斥', () {
      expect(judgePreference(reactions({Reaction.reject: 2, Reaction.accept: 1}), today: today),
          PreferenceLevel.reject);
    });
    test('只有 2 筆 → 紀錄不足', () {
      expect(judgePreference(reactions({Reaction.reject: 1, Reaction.like: 1}), today: today), isNull);
    });
    test('邊界：平均剛好 -0.2 是接受、剛好 0.2 是喜歡', () {
      expect(judgePreference(reactions({Reaction.reject: 1, Reaction.accept: 4}), today: today),
          PreferenceLevel.accept);
      expect(judgePreference(reactions({Reaction.like: 1, Reaction.accept: 4}), today: today),
          PreferenceLevel.like);
    });
    test('近 3 個月的筆數比較多時，用近 3 個月的全部紀錄', () {
      // 很久以前排斥 3 次,最近 12 次都喜歡:最近 10 筆和近 3 個月(12 筆)都是喜歡。
      final old = reactions({Reaction.reject: 3}, day: const Day(2025, 1, 1));
      final recent = reactions({Reaction.like: 12}, day: const Day(2026, 9, 1));
      expect(judgePreference([...old, ...recent], today: today), PreferenceLevel.like);
    });
    test('近 3 個月沒有紀錄時，看最近 10 筆', () {
      final old = reactions({Reaction.reject: 5}, day: const Day(2025, 1, 1));
      expect(judgePreference(old, today: today), PreferenceLevel.reject);
    });
    test('早期的紀錄不會永遠決定結果', () {
      final early = reactions({Reaction.reject: 10}, day: const Day(2026, 1, 1));
      final later = reactions({Reaction.like: 10}, day: const Day(2026, 8, 1));
      expect(judgePreference([...early, ...later], today: today), PreferenceLevel.like);
    });
    test('近 3 個月從今天往前推 3 個月的同一天（含）起算', () {
      final edge = reactions({Reaction.like: 11}, day: const Day(2026, 7, 23));
      final before = reactions({Reaction.reject: 1}, day: const Day(2026, 7, 22));
      // 近 3 個月 = 11 筆喜歡(含 7/23),比最近 10 筆多 → 採用近 3 個月。
      expect(judgePreference([...edge, ...before], today: today), PreferenceLevel.like);
    });
  });
}
