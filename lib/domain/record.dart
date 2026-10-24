import '../core/time.dart';

/// 過敏狀況(單選,可取消,未選=不納入運算)。代碼是匯出格式的固定值。
enum Allergy {
  none('none', '沒有過敏狀況', 0),
  nextDay('next_day', '隔天發生過敏', 3),
  sameDay('same_day', '當天發生過敏', 10);

  const Allergy(this.code, this.label, this.score10);

  final String code;
  final String label;

  /// 分數 ×10(沒有 0、隔天 0.3、當天 1),用整數算避免浮點誤差。
  final int score10;

  static Allergy? fromCode(String? code) => code == null ? null : values.firstWhere((a) => a.code == code);

  /// 畫面上的順序:沒有過敏狀況 / 當天發生過敏 / 隔天發生過敏(SPEC 第 7 節)。
  static const display = [Allergy.none, Allergy.sameDay, Allergy.nextDay];
}

/// 用食反應(單選,可取消,未選=不納入運算)。
enum Reaction {
  reject('reject', '排斥', -1),
  accept('accept', '接受', 0),
  like('like', '喜歡', 1);

  const Reaction(this.code, this.label, this.score);

  final String code;
  final String label;
  final int score;

  static Reaction? fromCode(String? code) => code == null ? null : values.firstWhere((r) => r.code == code);
}

/// 一筆副食品紀錄。
class FeedRecord {
  const FeedRecord({
    required this.id,
    required this.babySeq,
    required this.timeUtcMs,
    required this.tzOffsetMinutes,
    required this.foodId,
    required this.preparedCenti,
    required this.preparedUnitId,
    required this.eatenCenti,
    required this.eatenUnitId,
    required this.allergy,
    required this.reaction,
    required this.note,
    required this.photoIds,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String id;
  final int babySeq;
  final int timeUtcMs;
  final int tzOffsetMinutes;
  final int foodId;
  final int preparedCenti;
  final int preparedUnitId;
  final int eatenCenti;
  final int eatenUnitId;
  final Allergy? allergy;
  final Reaction? reaction;
  final String note;
  final List<String> photoIds;
  final int createdAtMs;
  final int updatedAtMs;

  Day get day => TimeRules.localDay(timeUtcMs, tzOffsetMinutes);

  DateTime get localTime => TimeRules.localTime(timeUtcMs, tzOffsetMinutes);
}
