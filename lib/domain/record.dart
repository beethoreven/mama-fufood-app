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

/// 腹瀉或嘔吐(可取消,未選=不納入運算)。代碼是匯出格式的固定值(匯出格式第 1 版起)。
/// 「正常」和另外兩個互斥;腹瀉、嘔吐可以同時有。
enum Digestive {
  normal('normal', '正常', hasDiarrhea: false, hasVomiting: false),
  diarrhea('diarrhea', '腹瀉', hasDiarrhea: true, hasVomiting: false),
  vomiting('vomiting', '嘔吐', hasDiarrhea: false, hasVomiting: true),
  both('diarrhea_vomiting', '腹瀉、嘔吐', hasDiarrhea: true, hasVomiting: true);

  const Digestive(this.code, this.label, {required this.hasDiarrhea, required this.hasVomiting});

  final String code;
  final String label;
  final bool hasDiarrhea;
  final bool hasVomiting;

  static Digestive? fromCode(String? code) => code == null ? null : values.firstWhere((d) => d.code == code);

  /// 依勾選的腹瀉、嘔吐組出值(兩個都沒勾就是 null,不是「正常」)。
  static Digestive? fromFlags({required bool diarrhea, required bool vomiting}) => diarrhea && vomiting
      ? Digestive.both
      : diarrhea
          ? Digestive.diarrhea
          : vomiting
              ? Digestive.vomiting
              : null;
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
    this.digestive,
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

  /// 腹瀉或嘔吐;null = 沒填。
  final Digestive? digestive;
  final String note;
  final List<String> photoIds;
  final int createdAtMs;
  final int updatedAtMs;

  Day get day => TimeRules.localDay(timeUtcMs, tzOffsetMinutes);

  DateTime get localTime => TimeRules.localTime(timeUtcMs, tzOffsetMinutes);
}
