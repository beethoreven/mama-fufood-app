import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/data/catalog_source.dart';
import 'package:mama_fufood/data/database.dart';
import 'package:mama_fufood/data/store.dart';
import 'package:mama_fufood/domain/catalog.dart';
import 'package:mama_fufood/domain/dataset_rules.dart';

/// App 內建的公用資料(和後端的種子資料是同一份)。
DatasetEnvelope bundled(String name) => DatasetEnvelope.fromJson(
    jsonDecode(File('assets/datasets/$name.json').readAsStringSync()) as Map<String, dynamic>);

const newer = '20991231000000';

/// 內建的資料改一部分,當成伺服器傳來的新版本。
DatasetEnvelope edited(String name, void Function(Map<String, dynamic> content) edit, {String version = newer}) {
  final base = bundled(name);
  final content = jsonDecode(jsonEncode(base.content)) as Map<String, dynamic>;
  edit(content);
  return DatasetEnvelope(name: name, version: version, formatVersion: base.formatVersion, content: content);
}

Map<String, dynamic> item(Map<String, dynamic> content, String key, [int index = 0]) =>
    (content[key] as List)[index] as Map<String, dynamic>;

List<String> foodProblems(void Function(Map<String, dynamic>) edit) =>
    DatasetRules.problems(edited('food_list', edit), previous: bundled('food_list'));

List<String> unitProblems(void Function(Map<String, dynamic>) edit) =>
    DatasetRules.problems(edited('units', edit), previous: bundled('units'));

void main() {
  test('內建的公用資料合規則', () {
    for (final name in ['food_list', 'units']) {
      expect(DatasetRules.problems(bundled(name)), isEmpty, reason: name);
    }
  });

  group('食材清單', () {
    test('規則內的修改照常接受：改名、換圖示、停用、換分組、新增', () {
      expect(
          foodProblems((c) {
            item(c, 'foods')['name'] = '番薯';
            item(c, 'foods')['emoji'] = '👨‍👩‍👧'; // 組合 emoji 算一個字
            item(c, 'foods', 1)['disabled'] = true;
            item(c, 'foods', 2)['group_id'] = item(c, 'groups', 1)['id'];
            (c['foods'] as List).add({'id': 9999, 'group_id': 1, 'name': '新', 'emoji': '🍎', 'sort': 100001, 'disabled': false});
            (c['groups'] as List).add({'id': 999, 'name': '六個字的分組', 'emoji': '🌾', 'sort': 0, 'disabled': true});
          }),
          isEmpty);
    });

    test('名稱：空白、超過字數、不是文字、有存不進資料庫的字', () {
      expect(foodProblems((c) => item(c, 'foods')['name'] = ' '), ['food_name']);
      expect(foodProblems((c) => item(c, 'foods')['name'] = '四個字的'), ['food_name']);
      expect(foodProblems((c) => item(c, 'foods')['name'] = 3), ['food_name']);
      expect(foodProblems((c) => item(c, 'foods')['name'] = 'a\u0000'), ['food_name']);
      expect(foodProblems((c) => item(c, 'foods')['name'] = 'a\ud800'), ['food_name']);
      expect(foodProblems((c) => item(c, 'groups')['name'] = '七個字的分組名'), ['group_name']);
    });

    test('圖示要剛好一個字', () {
      expect(foodProblems((c) => item(c, 'foods')['emoji'] = '🍎🍌'), ['food_emoji']);
      expect(foodProblems((c) => item(c, 'foods')['emoji'] = ''), ['food_emoji']);
      expect(foodProblems((c) => item(c, 'groups')['emoji'] = null), ['group_emoji']);
    });

    test('ID、分組、排序、停用的格式', () {
      expect(foodProblems((c) => item(c, 'foods', 1)['id'] = item(c, 'foods')['id']), ['food_duplicate_id', 'food_removed']);
      expect(foodProblems((c) => item(c, 'foods')['id'] = '1'), ['food_id', 'food_removed']);
      expect(foodProblems((c) => item(c, 'foods')['group_id'] = 12345), ['food_group_missing']);
      expect(foodProblems((c) => item(c, 'foods')['sort'] = -1), ['food_sort']);
      expect(foodProblems((c) => item(c, 'foods')['sort'] = 1.5), ['food_sort']);
      expect(foodProblems((c) => item(c, 'foods')['disabled'] = 'no'), ['food_disabled']);
      expect(foodProblems((c) => c['foods'] = <String, dynamic>{}), ['foods_shape']);
      expect(foodProblems((c) => (c['foods'] as List).add('x')), ['foods_shape']);
    });

    test('手機上有的 ID 不能不見（不用的是停用，不是刪掉）', () {
      expect(foodProblems((c) => (c['foods'] as List).removeLast()), ['food_removed']);
      expect(
          foodProblems((c) {
            final last = (c['groups'] as List).removeLast() as Map;
            for (final f in c['foods'] as List) {
              if ((f as Map)['group_id'] == last['id']) f['group_id'] = 1;
            }
          }),
          ['group_removed']);
    });
  });

  group('單位', () {
    test('規則內的修改照常接受：改名、換預設、停用原本的預設', () {
      expect(
          unitProblems((c) {
            item(c, 'units')['default'] = false;
            item(c, 'units')['disabled'] = true;
            item(c, 'units', 1)['default'] = true;
            item(c, 'units', 1)['name'] = '四個字的';
          }),
          isEmpty);
    });

    test('預設剛好一個，而且沒有停用', () {
      expect(unitProblems((c) => item(c, 'units')['default'] = false), ['unit_default_count']);
      expect(unitProblems((c) => item(c, 'units', 1)['default'] = true), ['unit_default_count']);
      expect(unitProblems((c) => item(c, 'units')['disabled'] = true), ['unit_default_disabled']);
      expect(unitProblems((c) => item(c, 'units')['default'] = 'yes'), ['unit_default', 'unit_default_count']);
    });

    test('名稱與 ID', () {
      expect(unitProblems((c) => item(c, 'units')['name'] = '五個字的字'), ['unit_name']);
      expect(unitProblems((c) => (c['units'] as List).removeLast()), ['unit_removed']);
    });
  });

  group('版本', () {
    test('要是 14 位數字，而且比手機上的新', () {
      final previous = bundled('units');
      List<String> withVersion(String v) =>
          DatasetRules.problems(edited('units', (_) {}, version: v), previous: previous);
      expect(withVersion(newer), isEmpty);
      expect(withVersion(previous.version), ['version_not_newer']);
      expect(withVersion('20200101000000'), ['version_not_newer']);
      expect(withVersion('2099123100000'), ['version_format']);
      expect(withVersion('9' * 30), ['version_format']);
    });

    test('不認得的資料集不收', () {
      expect(DatasetRules.problems(const DatasetEnvelope(name: 'other', version: newer, formatVersion: 1, content: {})),
          ['unknown_dataset']);
    });
  });

  group('CatalogSource', () {
    late Store store;
    late CatalogSource source;

    setUp(() {
      store = Store(AppDb(NativeDatabase.memory()));
      source = CatalogSource(store, loadAsset: (path) => File(path).readAsString());
    });
    tearDown(() => store.db.close());

    test('合規則的存起來；不合規則的不存，繼續用手機上的那份', () async {
      expect(await source.apply(edited('food_list', (c) => item(c, 'foods')['name'] = '番薯')), DatasetApply.applied);
      expect((await source.current('food_list')).version, newer);

      final bad = edited('food_list', (c) => (c['foods'] as List).removeLast(), version: '20991231000001');
      expect(await source.apply(bad), DatasetApply.rejected);
      final current = await source.current('food_list');
      expect(current.version, newer);
      expect(item(current.content, 'foods')['name'], '番薯');
    });

    test('不支援的資料格式不存', () async {
      final env = edited('units', (_) {});
      expect(
          await source.apply(DatasetEnvelope(name: 'units', version: env.version, formatVersion: 99, content: env.content)),
          DatasetApply.unsupported);
      expect(await store.getDataset('units'), isNull);
    });

    test('存起來的那份不合規則（加上檢查之前存的）時，改用內建的', () async {
      await store.putDataset(edited('food_list', (c) => item(c, 'foods')['name'] = '太長的名字'));
      final current = await source.current('food_list');
      expect(current.version, bundled('food_list').version);
      expect(Catalog.fromEnvelopes(current, await source.current('units')).food(1)?.name, '十倍粥');
    });
  });
}
