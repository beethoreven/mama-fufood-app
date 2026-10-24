import '../core/time.dart';
import 'catalog.dart';
import 'record.dart';

/// 頁籤 2「統計」(SPEC 第 7 節):依分組(依排序序號)列出有紀錄的食材(組內依食材
/// 排序序號),每個食材只加總「食用量」,各單位分開加總(克與毫升換不準),總量 0 的
/// 單位不顯示;有紀錄但所有單位都是 0 → 「寶寶不吃」(只看數量,不和用食反應交叉比對)。
/// 沒有紀錄的食材不列入;不認得的食材或單位不列入。

class StatsFilter {
  const StatsFilter({required this.year, this.month, this.day});

  final int year;
  final int? month;
  /// 日要先選了月才有作用(畫面上沒選月時,日是鎖住的)。
  final int? day;

  bool matches(Day d) =>
      d.year == year && (month == null || d.month == month) && (day == null || month == null || d.day == day);
}

class FoodTotal {
  FoodTotal(this.food);

  final Food food;
  final Map<int, int> centiByUnit = {};
  int records = 0;

  /// 有紀錄,但所有單位都是 0。
  bool get refused => centiByUnit.values.every((v) => v == 0);
}

class GroupTotals {
  GroupTotals(this.group, this.foods);

  final FoodGroup group;
  final List<FoodTotal> foods;
}

List<GroupTotals> computeStats(Iterable<FeedRecord> records, Catalog catalog, StatsFilter filter) {
  final totals = <int, FoodTotal>{};
  for (final r in records) {
    if (!filter.matches(r.day)) continue;
    if (!catalog.knows(foodId: r.foodId, preparedUnitId: r.preparedUnitId, eatenUnitId: r.eatenUnitId)) continue;
    final t = totals.putIfAbsent(r.foodId, () => FoodTotal(catalog.food(r.foodId)!));
    t.records += 1;
    t.centiByUnit.update(r.eatenUnitId, (v) => v + r.eatenCenti, ifAbsent: () => r.eatenCenti);
  }
  final result = <GroupTotals>[];
  for (final g in catalog.groups) {
    final foods = [
      for (final f in catalog.foodsInGroup(g.id))
        if (totals.containsKey(f.id)) totals[f.id]!,
    ];
    if (foods.isNotEmpty) result.add(GroupTotals(g, foods));
  }
  return result;
}

/// 顯示用:各單位依單位排序,只列總量 > 0 的。
List<MapEntry<Unit, int>> visibleUnitTotals(FoodTotal total, Catalog catalog) {
  final list = [
    for (final e in total.centiByUnit.entries)
      if (e.value > 0 && catalog.unit(e.key) != null) MapEntry(catalog.unit(e.key)!, e.value),
  ]..sort((a, b) => a.key.sort != b.key.sort ? a.key.sort.compareTo(b.key.sort) : a.key.id.compareTo(b.key.id));
  return list;
}
