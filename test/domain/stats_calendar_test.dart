import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/core/text.dart';
import 'package:mama_fufood/core/time.dart';
import 'package:mama_fufood/domain/calendar.dart';
import 'package:mama_fufood/domain/catalog.dart';
import 'package:mama_fufood/domain/record.dart';
import 'package:mama_fufood/domain/stats.dart';

Catalog catalog() => Catalog(
      groups: const [
        FoodGroup(id: 1, name: '五穀', emoji: '🌾', sort: 2),
        FoodGroup(id: 2, name: '水果', emoji: '🍎', sort: 1),
      ],
      foods: const [
        Food(id: 10, groupId: 1, name: '十倍粥', emoji: '🥣', sort: 1),
        Food(id: 11, groupId: 1, name: '燕麥', emoji: '🌾', sort: 2),
        Food(id: 20, groupId: 2, name: '香蕉', emoji: '🍌', sort: 1),
        Food(id: 21, groupId: 2, name: '芭樂', emoji: '🍎', sort: 2, disabled: true),
      ],
      units: const [
        Unit(id: 1, name: '克', sort: 1, isDefault: true),
        Unit(id: 2, name: '毫升', sort: 2),
      ],
      foodVersion: 'v',
      unitVersion: 'v',
    );

FeedRecord r(int food, int eatenCenti, int unit, Day day) => FeedRecord(
      id: newId(),
      babySeq: 1,
      timeUtcMs: TimeRules.toUtcMs(day, 9, 0, 480),
      tzOffsetMinutes: 480,
      foodId: food,
      preparedCenti: 0,
      preparedUnitId: 1,
      eatenCenti: eatenCenti,
      eatenUnitId: unit,
      allergy: null,
      reaction: null,
      note: '',
      photoIds: const [],
      createdAtMs: 0,
      updatedAtMs: 0,
    );

void main() {
  test('統計依分組排序、各單位分開加總、全部 0 是寶寶不吃、不認得的不列入', () {
    final day = const Day(2026, 10, 5);
    final records = [
      r(10, 2550, 1, day),
      r(10, 450, 1, day),
      r(10, 3000, 2, day),
      r(11, 0, 1, day),
      r(20, 1000, 1, const Day(2026, 9, 30)),
      r(99, 1000, 1, day), // 不認得的食材
      r(21, 500, 1, day), // 停用的食材:舊紀錄照常算
    ];
    final stats = computeStats(records, catalog(), const StatsFilter(year: 2026, month: 10));
    expect(stats.map((g) => g.group.name), ['水果', '五穀']);
    final fruit = stats.first.foods;
    expect(fruit.map((f) => f.food.id), [21], reason: '香蕉是 9 月的，不在篩選範圍');
    final grains = stats.last.foods;
    expect(grains.map((f) => f.food.id), [10, 11]);
    expect(grains.first.centiByUnit, {1: 3000, 2: 3000});
    expect(grains.last.refused, isTrue);
    expect(visibleUnitTotals(grains.last, catalog()), isEmpty);
  });

  test('日要先選月才有作用', () {
    expect(const StatsFilter(year: 2026, day: 5).matches(const Day(2026, 3, 9)), isTrue);
    expect(const StatsFilter(year: 2026, month: 3, day: 5).matches(const Day(2026, 3, 9)), isFalse);
  });

  test('月曆格子依週起始日排列', () {
    // 2026-10-01 是星期四。
    final monday = monthGrid(2026, 10, weekStartsMonday: true);
    expect(monday.first.take(3), everyElement(isNull));
    expect(monday.first[3], const Day(2026, 10, 1));
    final sunday = monthGrid(2026, 10, weekStartsMonday: false);
    expect(sunday.first[4], const Day(2026, 10, 1));
    expect(sunday.expand((w) => w).whereType<Day>().length, 31);
    // 6 週的月份:2026-08-01 是星期六,週一起始時要 6 週。
    expect(monthGrid(2026, 8, weekStartsMonday: true).length, 6);
  });

  test('月曆每格最多三排，超過 3 筆第三排是「…」', () {
    expect(cellRows(3), (shown: 3, more: false));
    expect(cellRows(4), (shown: 2, more: true));
  });

  test('數量：百分之一的整數與文字互換', () {
    expect(Amount.parse('25.5'), 2550);
    expect(Amount.parse('999.99'), 99999);
    expect(Amount.parse('1000'), isNull);
    expect(Amount.parse('1.234'), isNull);
    expect(Amount.parse(''), 0);
    expect(Amount.format(2550), '25.5');
    expect(Amount.format(2505), '25.05');
    expect(Amount.format(3000), '30');
    expect(Amount.toJson(3000), 30);
    expect(Amount.toJson(2550), 25.5);
    expect(Amount.fromJson(25.5), 2550);
    expect(Amount.fromJson(1.005), isNull);
    expect(Amount.fromJson(1000), isNull);
  });

  test('時間：UTC 加時區偏移得到月曆上的日期', () {
    // 台北 10/24 07:30 = UTC 10/23 23:30。
    final utc = TimeRules.toUtcMs(const Day(2026, 10, 24), 7, 30, 480);
    expect(TimeRules.isoMinute(utc), '2026-10-23T23:30:00Z');
    expect(TimeRules.localDay(utc, 480), const Day(2026, 10, 24));
    expect(TimeRules.localDay(utc, -300), const Day(2026, 10, 23));
    expect(TimeRules.formatOffset(480), '+08:00');
    expect(TimeRules.formatOffset(-570), '-09:30');
    expect(TimeRules.parseOffset('+05:45'), 345);
    expect(const Day(2026, 5, 31).minusMonths(3), const Day(2026, 3, 3));
  });

  test('字數：一個 emoji 算一個字', () {
    expect(charCount('小寶👨‍👩‍👧'), 3);
  });
}
