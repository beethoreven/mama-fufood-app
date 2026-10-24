import '../core/time.dart';
import 'record.dart';

/// 判斷規則,**寫死在 App 內**(SPEC 第 8 節;要改就發新版 App,
/// 必要時強制更新)。規則改了,判斷邏輯說明頁(assets/texts/judgement_guide.md)要在同一版一起改。
///
/// 只是把使用者自己的紀錄整理成比較容易看的樣子,不是醫療判斷。
/// 「紀錄不足」回傳 null,畫面上不放圖示、位置留空。

enum AllergyLevel { stable, risk, allergic }

enum PreferenceLevel { reject, accept, like }

/// 過敏:只計算有填「過敏狀況」的紀錄。分數:沒有 0、隔天 0.3、當天 1。
/// 平均 0~0.2 → 穩定;>0.2~0.7 → 風險;>0.7~1 → 過敏。
/// 最低標示:任一筆當天 → 至少風險;≥2 筆當天 → 過敏;≥2 筆隔天 → 至少風險(只有 1 筆隔天只依平均)。
/// 筆數 < 3 且沒有任何當天或隔天 → 紀錄不足;只要出現過當天或隔天,就視為足夠。
AllergyLevel? judgeAllergy(Iterable<FeedRecord> records) {
  final marked = records.where((r) => r.allergy != null).toList();
  final sameDay = marked.where((r) => r.allergy == Allergy.sameDay).length;
  final nextDay = marked.where((r) => r.allergy == Allergy.nextDay).length;
  if (marked.length < 3 && sameDay == 0 && nextDay == 0) return null;

  final n = marked.length;
  final sum10 = marked.fold<int>(0, (s, r) => s + r.allergy!.score10);
  // 平均 = sum10 / (10n);和 0.2、0.7 比較改成整數:sum10 ≤ 2n、sum10 ≤ 7n。
  var level = sum10 <= 2 * n
      ? AllergyLevel.stable
      : sum10 <= 7 * n
          ? AllergyLevel.risk
          : AllergyLevel.allergic;

  if (sameDay >= 2) {
    level = AllergyLevel.allergic;
  } else if ((sameDay >= 1 || nextDay >= 2) && level == AllergyLevel.stable) {
    level = AllergyLevel.risk;
  }
  return level;
}

/// 喜好:只計算有填「用食反應」的紀錄。分數:排斥 -1、接受 0、喜歡 1。
/// 取「最近 10 筆」與「近 3 個月全部紀錄」中**筆數較多**的那一組(一樣多時用最近 10 筆)。
/// 平均 -1~<-0.2 → 排斥;-0.2~<0.2 → 接受;0.2~1 → 喜歡。採用的那組 < 3 筆 → 紀錄不足。
///
/// 時間的定義:一律看紀錄上的日期時間;「近 3 個月」= 紀錄日期在
/// 今天往前推 3 個月的同一天(含)之後,未來日期的紀錄也算。
PreferenceLevel? judgePreference(Iterable<FeedRecord> records, {required Day today}) {
  final marked = records.where((r) => r.reaction != null).toList()
    ..sort((a, b) => b.timeUtcMs.compareTo(a.timeUtcMs));
  final last10 = marked.take(10).toList();
  final cutoff = today.minusMonths(3);
  final recent = marked.where((r) => cutoff <= r.day).toList();
  final chosen = recent.length > last10.length ? recent : last10;
  if (chosen.length < 3) return null;

  final n = chosen.length;
  final sum = chosen.fold<int>(0, (s, r) => s + r.reaction!.score);
  // 平均 = sum / n;和 -0.2、0.2 比較改成整數:5·sum < -n、5·sum < n。
  if (5 * sum < -n) return PreferenceLevel.reject;
  if (5 * sum < n) return PreferenceLevel.accept;
  return PreferenceLevel.like;
}
