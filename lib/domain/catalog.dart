import 'dart:convert';

/// 公用資料:副食品清單(分組、食材)與單位(SPEC 第 3 節)。
///
/// - ID 永遠不可改、不可刪、不可重用;不再使用的項目用「停用」標記:不出現在新增紀錄
///   的選單,舊紀錄照常顯示。
/// - 紀錄用到這支手機還不認得的食材或單位(公用資料還沒更新)時,那筆紀錄原樣保存、
///   先不顯示、不列入統計與判斷,資料更新後自動恢復(第 4 節「不認得的資料」)。

class FoodGroup {
  const FoodGroup({required this.id, required this.name, required this.emoji, required this.sort, this.disabled = false});

  factory FoodGroup.fromJson(Map<String, dynamic> j) => FoodGroup(
      id: j['id'] as int, name: j['name'] as String, emoji: j['emoji'] as String,
      sort: j['sort'] as int, disabled: j['disabled'] as bool? ?? false);

  final int id;
  final String name;
  final String emoji;
  final int sort;
  final bool disabled;
}

class Food {
  const Food({required this.id, required this.groupId, required this.name, required this.emoji,
      required this.sort, this.disabled = false});

  factory Food.fromJson(Map<String, dynamic> j) => Food(
      id: j['id'] as int, groupId: j['group_id'] as int, name: j['name'] as String,
      emoji: j['emoji'] as String, sort: j['sort'] as int, disabled: j['disabled'] as bool? ?? false);

  final int id;
  final int groupId;
  final String name;
  final String emoji;
  final int sort;
  final bool disabled;
}

class Unit {
  const Unit({required this.id, required this.name, required this.sort, this.isDefault = false, this.disabled = false});

  factory Unit.fromJson(Map<String, dynamic> j) => Unit(
      id: j['id'] as int, name: j['name'] as String, sort: j['sort'] as int,
      isDefault: j['default'] as bool? ?? false, disabled: j['disabled'] as bool? ?? false);

  final int id;
  final String name;
  final int sort;
  final bool isDefault;
  final bool disabled;
}

/// 一份資料集的外殼:名稱、版本(發布時間)、資料格式版本、內容。
class DatasetEnvelope {
  const DatasetEnvelope({required this.name, required this.version, required this.formatVersion, required this.content});

  factory DatasetEnvelope.fromJson(Map<String, dynamic> j) => DatasetEnvelope(
      name: j['name'] as String, version: j['version'] as String,
      formatVersion: j['format_version'] as int, content: (j['content'] as Map).cast<String, dynamic>());

  final String name;
  final String version;
  final int formatVersion;
  final Map<String, dynamic> content;

  Map<String, dynamic> toJson() =>
      {'name': name, 'version': version, 'format_version': formatVersion, 'content': content};

  String encode() => jsonEncode(toJson());
}

/// App 支援的資料格式版本。後端回「需要新版 App」時,代表資料的格式比這裡新。
const supportedDatasetFormats = {'food_list': [1], 'units': [1]};

class Catalog {
  Catalog({required List<FoodGroup> groups, required List<Food> foods, required List<Unit> units,
      required this.foodVersion, required this.unitVersion})
      : groups = [...groups]..sort((a, b) => a.sort != b.sort ? a.sort.compareTo(b.sort) : a.id.compareTo(b.id)),
        units = [...units]..sort((a, b) => a.sort != b.sort ? a.sort.compareTo(b.sort) : a.id.compareTo(b.id)),
        _foods = {for (final f in foods) f.id: f},
        _groups = {for (final g in groups) g.id: g},
        _units = {for (final u in units) u.id: u};

  factory Catalog.fromEnvelopes(DatasetEnvelope foodList, DatasetEnvelope unitList) => Catalog(
        groups: [for (final g in foodList.content['groups'] as List) FoodGroup.fromJson((g as Map).cast())],
        foods: [for (final f in foodList.content['foods'] as List) Food.fromJson((f as Map).cast())],
        units: [for (final u in unitList.content['units'] as List) Unit.fromJson((u as Map).cast())],
        foodVersion: foodList.version,
        unitVersion: unitList.version,
      );

  final List<FoodGroup> groups;
  final List<Unit> units;
  final Map<int, Food> _foods;
  final Map<int, FoodGroup> _groups;
  final Map<int, Unit> _units;
  final String foodVersion;
  final String unitVersion;

  Food? food(int id) => _foods[id];
  FoodGroup? group(int id) => _groups[id];
  Unit? unit(int id) => _units[id];

  /// 分組由食材清單查出來(紀錄不另存分組 ID)。
  FoodGroup? groupOfFood(int foodId) {
    final f = _foods[foodId];
    return f == null ? null : _groups[f.groupId];
  }

  /// 這筆紀錄的食材與單位這支手機都認得,才顯示、才算進統計與判斷。
  bool knows({required int foodId, required int preparedUnitId, required int eatenUnitId}) =>
      _foods.containsKey(foodId) &&
      _groups.containsKey(_foods[foodId]!.groupId) &&
      _units.containsKey(preparedUnitId) &&
      _units.containsKey(eatenUnitId);

  /// 新增紀錄時能選的分組(停用的不出現;組內沒有可選食材的也不出現)。
  List<FoodGroup> selectableGroups() =>
      [for (final g in groups) if (!g.disabled && selectableFoods(g.id).isNotEmpty) g];

  List<Food> selectableFoods(int groupId) => foodsInGroup(groupId).where((f) => !f.disabled).toList();

  List<Food> foodsInGroup(int groupId) {
    final list = _foods.values.where((f) => f.groupId == groupId).toList()
      ..sort((a, b) => a.sort != b.sort ? a.sort.compareTo(b.sort) : a.id.compareTo(b.id));
    return list;
  }

  List<Unit> selectableUnits() => units.where((u) => !u.disabled).toList();

  Unit get defaultUnit => units.firstWhere((u) => u.isDefault && !u.disabled,
      orElse: () => units.firstWhere((u) => !u.disabled, orElse: () => units.first));
}
