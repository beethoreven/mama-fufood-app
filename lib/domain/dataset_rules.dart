import '../core/constants.dart';
import '../core/text.dart';
import 'catalog.dart';

/// 公用資料(副食品清單、單位)的內容規則,和後台輸入、發布時的檢查一樣。
///
/// 每日檢查收到的新內容先過這裡,不合規則就不存,繼續用手機上的那份;存在手機上的那份
/// 每次讀出來也再檢查一次。這樣就算後端被入侵或回應被竄改,也只能在規則內改內容,
/// 不能把清單弄壞、讓 App 當掉,或讓既有紀錄用到的食材消失。
///
/// - 名稱:去掉頭尾空白後不能是空的;食材 [Limits.foodNameMaxChars]、分組 [Limits.groupNameMaxChars]、
///   單位 [Limits.unitNameMaxChars] 個字以內(一個 emoji 算一個字,見 [charCount])。
/// - 圖示(分組、食材):剛好一個字。
/// - ID 是正整數,同一種裡不重複;食材的分組要在同一份清單裡;排序是 0 以上的整數;
///   停用、預設要是是或否。
/// - 單位:預設剛好一個,而且沒有停用。
/// - 不能有存不進資料庫的字(NUL、落單的代理字元),後台本來就不收這些字。
/// - 版本是 14 位數字(發布時間,UTC 的年月日時分秒)。版本格式不對的話,之後每次檢查
///   都會把它送回後端、被當成格式錯誤,清單就再也更新不了。
/// - 和手機上目前用的那份比:版本要比較新(後端的版本只會往上),那份有的 ID 都還要在
///   (ID 永遠不可刪,不用的項目是停用)。
///
/// ★ 規則允許改名(例如修正錯字),所以在規則內的改名擋不住。
abstract final class DatasetRules {
  static final _version = RegExp(r'^\d{14}$');

  /// 不合規則的地方,用代碼表示(不含內容,可以寫進記錄檔);空的就是合規則。
  /// [previous] 是手機上目前用的那份;有給的話,另外檢查版本比它新、它有的 ID 都還在。
  static List<String> problems(DatasetEnvelope env, {DatasetEnvelope? previous}) {
    final found = <String>{};
    if (!_version.hasMatch(env.version)) found.add('version_format');
    if (previous != null && env.version.compareTo(previous.version) <= 0) found.add('version_not_newer');
    switch (env.name) {
      case 'food_list':
        _foodList(env.content, previous?.content, found);
      case 'units':
        _units(env.content, previous?.content, found);
      default:
        found.add('unknown_dataset');
    }
    return found.toList()..sort();
  }

  static void _foodList(Map<String, dynamic> content, Map<String, dynamic>? previous, Set<String> found) {
    final groups = _items(content, 'groups', found);
    final foods = _items(content, 'foods', found);
    if (groups == null || foods == null) return;
    final groupIds = _common(groups, 'group', Limits.groupNameMaxChars, found);
    final foodIds = _common(foods, 'food', Limits.foodNameMaxChars, found);
    for (final f in foods) {
      if (!groupIds.contains(f['group_id'])) found.add('food_group_missing');
    }
    if (previous != null) {
      if (!groupIds.containsAll(_ids(previous['groups']))) found.add('group_removed');
      if (!foodIds.containsAll(_ids(previous['foods']))) found.add('food_removed');
    }
  }

  static void _units(Map<String, dynamic> content, Map<String, dynamic>? previous, Set<String> found) {
    final units = _items(content, 'units', found);
    if (units == null) return;
    final ids = _common(units, 'unit', Limits.unitNameMaxChars, found, hasEmoji: false);
    if (units.any((u) => u['default'] is! bool)) found.add('unit_default');
    final defaults = units.where((u) => u['default'] == true).toList();
    if (defaults.length != 1) {
      found.add('unit_default_count');
    } else if (defaults.single['disabled'] != false) {
      found.add('unit_default_disabled');
    }
    if (previous != null && !ids.containsAll(_ids(previous['units']))) found.add('unit_removed');
  }

  /// content[key] 要是一串物件。
  static List<Map<String, dynamic>>? _items(Map<String, dynamic> content, String key, Set<String> found) {
    final raw = content[key];
    if (raw is! List || raw.any((item) => item is! Map)) {
      found.add('${key}_shape');
      return null;
    }
    return [for (final item in raw) (item as Map).cast<String, dynamic>()];
  }

  /// 分組、食材、單位共同的欄位。回傳這一種的 ID。
  static Set<int> _common(List<Map<String, dynamic>> items, String kind, int nameMax, Set<String> found,
      {bool hasEmoji = true}) {
    final ids = <int>{};
    for (final item in items) {
      final id = item['id'];
      if (id is! int || id < 1) {
        found.add('${kind}_id');
      } else if (!ids.add(id)) {
        found.add('${kind}_duplicate_id');
      }
      final name = item['name'];
      if (name is! String || !_storable(name) || name.trim().isEmpty || charCount(name) > nameMax) {
        found.add('${kind}_name');
      }
      final emoji = item['emoji'];
      if (hasEmoji && (emoji is! String || !_storable(emoji) || charCount(emoji.trim()) != 1)) {
        found.add('${kind}_emoji');
      }
      final sort = item['sort'];
      if (sort is! int || sort < 0) found.add('${kind}_sort');
      if (item['disabled'] is! bool) found.add('${kind}_disabled');
    }
    return ids;
  }

  /// 存不進資料庫的字:NUL 與落單的代理字元(成對的代理字元是一個 emoji,runes 會合成一個碼位)。
  static bool _storable(String text) => !text.runes.any((r) => r == 0 || (r >= 0xD800 && r <= 0xDFFF));

  static Set<int> _ids(Object? list) => {
        if (list is List)
          for (final item in list)
            if (item is Map && item['id'] is int) item['id'] as int,
      };
}
