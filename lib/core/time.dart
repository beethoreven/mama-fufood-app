/// 時間的規則(SPEC 第 4、13 節):
/// - 紀錄的時間一律存 UTC,並同時存記錄當下的時區偏移(例如 +08:00);
///   月曆上的日期 = UTC 時間加上那個偏移,出國也不會跑掉。
/// - 「一天」的上限(每日檢查、意見回饋)以台北時間計,和後端一致。
library;

/// 一個沒有時區的日期(年月日)。月曆、統計、每日 10 筆都用它。
class Day implements Comparable<Day> {
  const Day(this.year, this.month, this.day);

  factory Day.of(DateTime dt) => Day(dt.year, dt.month, dt.day);

  factory Day.parse(String text) {
    final parts = text.split('-').map(int.parse).toList();
    return Day(parts[0], parts[1], parts[2]);
  }

  final int year;
  final int month;
  final int day;

  /// 當成 UTC 的午夜,只用來做日期運算(不代表真的時刻)。
  DateTime get asUtc => DateTime.utc(year, month, day);

  Day addDays(int days) => Day.of(asUtc.add(Duration(days: days)));

  /// 往前推 n 個月的同一天(月底的日子由 DateTime 自動往後進位)。
  Day minusMonths(int months) => Day.of(DateTime.utc(year, month - months, day));

  /// 1 = 星期一 … 7 = 星期日。
  int get weekday => asUtc.weekday;

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(Day other) => asUtc.compareTo(other.asUtc);

  bool operator <(Day other) => compareTo(other) < 0;
  bool operator <=(Day other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is Day && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

abstract final class TimeRules {
  static const taipeiOffsetMinutes = 8 * 60;

  /// 現在。測試會換掉。
  static DateTime Function() now = DateTime.now;

  static Day taipeiToday() =>
      Day.of(now().toUtc().add(const Duration(minutes: taipeiOffsetMinutes)));

  /// 手機目前的時區偏移(分鐘)。
  static int currentOffsetMinutes() => now().timeZoneOffset.inMinutes;

  /// 紀錄在月曆上的日期。
  static Day localDay(int timeUtcMs, int offsetMinutes) => Day.of(
        DateTime.fromMillisecondsSinceEpoch(timeUtcMs, isUtc: true)
            .add(Duration(minutes: offsetMinutes)),
      );

  /// 紀錄當地時間(只用來顯示時:分)。
  static DateTime localTime(int timeUtcMs, int offsetMinutes) =>
      DateTime.fromMillisecondsSinceEpoch(timeUtcMs, isUtc: true).add(Duration(minutes: offsetMinutes));

  /// 把「當地的年月日時分」加上時區偏移,換成 UTC 毫秒(精確到分鐘)。
  static int toUtcMs(Day day, int hour, int minute, int offsetMinutes) =>
      DateTime.utc(day.year, day.month, day.day, hour, minute)
          .subtract(Duration(minutes: offsetMinutes))
          .millisecondsSinceEpoch;

  /// +08:00 這種寫法。
  static String formatOffset(int minutes) {
    final sign = minutes < 0 ? '-' : '+';
    final abs = minutes.abs();
    return '$sign${(abs ~/ 60).toString().padLeft(2, '0')}:${(abs % 60).toString().padLeft(2, '0')}';
  }

  static int? parseOffset(String text) {
    final m = RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(text);
    if (m == null) return null;
    final minutes = int.parse(m.group(2)!) * 60 + int.parse(m.group(3)!);
    return m.group(1) == '-' ? -minutes : minutes;
  }

  /// 匯出格式的時間:UTC、精確到分鐘,例如 2026-10-23T03:30:00Z。
  static String isoMinute(int utcMs) {
    final t = DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true);
    return '${Day.of(t)}T${_two(t.hour)}:${_two(t.minute)}:00Z';
  }

  /// 匯出格式的時間:UTC、到毫秒,例如 2026-10-23T03:31:12.345Z。
  static String isoMillis(int utcMs) {
    final t = DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true);
    return '${Day.of(t)}T${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}.'
        '${t.millisecond.toString().padLeft(3, '0')}Z';
  }

  static int? parseIso(String text) => DateTime.tryParse(text)?.toUtc().millisecondsSinceEpoch;

  static String _two(int v) => v.toString().padLeft(2, '0');
}
