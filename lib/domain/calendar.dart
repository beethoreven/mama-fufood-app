import '../core/time.dart';

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
