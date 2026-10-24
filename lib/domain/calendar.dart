import '../core/time.dart';
import 'record.dart';

/// 月曆的格子:依週起始日(星期一或星期日)排成 4~6 週。
/// 每格是一個日期;不屬於這個月的格子是 null(空白)。
List<List<Day?>> monthGrid(int year, int month, {required bool weekStartsMonday}) {
  final first = Day(year, month, 1);
  final daysInMonth = DateTime.utc(year, month + 1, 0).day;
  // 第一天前面要空幾格。weekday:1 = 星期一 … 7 = 星期日。
  final lead = weekStartsMonday ? first.weekday - 1 : first.weekday % 7;
  final cells = <Day?>[
    for (var i = 0; i < lead; i++) null,
    for (var d = 1; d <= daysInMonth; d++) Day(year, month, d),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
}

/// 星期的標題。
List<String> weekdayLabels({required bool weekStartsMonday}) =>
    weekStartsMonday ? const ['一', '二', '三', '四', '五', '六', '日'] : const ['日', '一', '二', '三', '四', '五', '六'];

/// 每格最多三排,每排一筆紀錄;超過 3 筆時第三排改成「…」(SPEC 第 7 節)。
/// 回傳要顯示的紀錄數,以及要不要放「…」。
({int shown, bool more}) cellRows(int count) => count <= 3 ? (shown: count, more: false) : (shown: 2, more: true);

/// 月曆上要標淡紅色的日子:有紀錄填了「當天發生過敏」的那一天,
/// 以及有紀錄填了「隔天發生過敏」的下一天。只是把紀錄標出來,不是判斷。
/// 要算某個月的格子時,傳入的紀錄要包含上個月最後一天(它的「隔天」是這個月 1 號)。
Set<Day> allergyMarkedDays(Iterable<FeedRecord> records) => {
      for (final r in records)
        if (r.allergy == Allergy.sameDay)
          r.day
        else if (r.allergy == Allergy.nextDay)
          r.day.addDays(1),
    };
