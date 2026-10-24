import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/time.dart';
import '../../domain/calendar.dart';
import '../../domain/catalog.dart';
import '../../domain/record.dart';
import '../../state/providers.dart';
import '../record/record_dialog.dart';
import '../theme.dart';
import '../widgets/wheel_picker.dart';
import 'day_list_dialog.dart';

/// 頁籤 1:行事曆(SPEC 第 7 節)。月曆頁因版面空間不放免責小字。
class CalendarTab extends ConsumerStatefulWidget {
  const CalendarTab({super.key});

  @override
  ConsumerState<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<CalendarTab> {
  late int _year;
  late int _month;
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    final today = Day.of(TimeRules.now());
    _year = today.year.clamp(Limits.yearMin, Limits.yearMax);
    _month = today.month;
  }

  bool get _atStart => _year == Limits.yearMin && _month == 1;

  bool get _atEnd => _year == Limits.yearMax && _month == 12;

  void _shift(int delta) {
    if ((delta < 0 && _atStart) || (delta > 0 && _atEnd)) return;
    setState(() {
      final m = DateTime.utc(_year, _month + delta);
      _year = m.year;
      _month = m.month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final baby = ref.watch(currentBabyProvider);
    final catalog = ref.watch(catalogProvider).value;
    final settings = settingsOf(ref);
    if (baby == null || catalog == null) return const SizedBox.shrink();
    final records = knownOnly(ref.watch(monthRecordsProvider((baby.seq, _year, _month))).value ?? const [], catalog);
    // 上個月最後一天填了「隔天發生過敏」的話,這個月 1 號也要標。
    final prevMonth = Day(_year, _month, 1).addDays(-1);
    final prevRecords =
        knownOnly(ref.watch(monthRecordsProvider((baby.seq, prevMonth.year, prevMonth.month))).value ?? const [], catalog);
    final allergyDays = allergyMarkedDays([...records, ...prevRecords.where((r) => r.day == prevMonth)]);
    final byDay = <Day, List<FeedRecord>>{};
    for (final r in records) {
      byDay.putIfAbsent(r.day, () => []).add(r);
    }
    final weeks = monthGrid(_year, _month, weekStartsMonday: settings.weekStartsMonday);
    final c = context.colors;
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return GestureDetector(
        // 左右滑動換月:拖曳超過一半寬度才換,只看距離,不看甩動速度。
        onHorizontalDragStart: (_) => _drag = 0,
        onHorizontalDragUpdate: (d) => setState(() => _drag += d.delta.dx),
        onHorizontalDragEnd: (_) {
          final threshold = width * Timing.monthSwipeFraction;
          if (_drag <= -threshold) _shift(1);
          if (_drag >= threshold) _shift(-1);
          setState(() => _drag = 0);
        },
        onHorizontalDragCancel: () => setState(() => _drag = 0),
        child: Column(children: [
          _header(context),
          Container(
            color: c.surface,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              for (final w in weekdayLabels(weekStartsMonday: settings.weekStartsMonday))
                Expanded(child: Center(child: Text(w, style: Theme.of(context).textTheme.labelSmall))),
            ]),
          ),
          Expanded(
            child: Transform.translate(
              offset: Offset(_drag.clamp(-width, width) * 0.35, 0),
              child: Column(children: [
                for (final week in weeks)
                  Expanded(
                    child: Row(children: [
                      for (final day in week)
                        Expanded(
                          child: day == null
                              ? Container(decoration: BoxDecoration(border: Border.all(color: c.border, width: 0.25)))
                              : _DayCell(
                                  day: day,
                                  records: byDay[day] ?? const [],
                                  catalog: catalog,
                                  allergy: allergyDays.contains(day),
                                  onTap: () => _openDay(context, baby.seq, day, byDay[day] ?? const []),
                                ),
                        ),
                    ]),
                  ),
              ]),
            ),
          ),
        ]),
      );
    });
  }

  Widget _header(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.surface,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          tooltip: '上個月',
          onPressed: _atStart ? null : () => _shift(-1),
          icon: Icon(Icons.chevron_left_rounded, color: _atStart ? c.muted.withValues(alpha: 0.4) : c.text),
        ),
        PickerButton(
          text: '$_year 年',
          onTap: () async {
            final y = await showWheelPicker<int>(context,
                title: '年',
                items: [for (var y = Limits.yearMin; y <= Limits.yearMax; y++) y],
                initial: _year,
                label: (y) => '$y 年');
            if (y != null) setState(() => _year = y);
          },
        ),
        const SizedBox(width: 8),
        PickerButton(
          text: '$_month 月',
          onTap: () async {
            final m = await showWheelPicker<int>(context,
                title: '月', items: [for (var m = 1; m <= 12; m++) m], initial: _month, label: (m) => '$m 月');
            if (m != null) setState(() => _month = m);
          },
        ),
        IconButton(
          tooltip: '下個月',
          onPressed: _atEnd ? null : () => _shift(1),
          icon: Icon(Icons.chevron_right_rounded, color: _atEnd ? c.muted.withValues(alpha: 0.4) : c.text),
        ),
      ]),
    );
  }

  Future<void> _openDay(BuildContext context, int babySeq, Day day, List<FeedRecord> records) async {
    if (records.isEmpty) {
      // 點沒紀錄的日子 → 直接開新增介面。
      await showRecordDialog(context, babySeq: babySeq, day: day);
      return;
    }
    await showDayListDialog(context, babySeq: babySeq, day: day);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell(
      {required this.day, required this.records, required this.catalog, required this.allergy, required this.onTap});

  final Day day;

  /// 當天或前一天的紀錄有過敏狀況:格子標淡紅色(見 allergyMarkedDays)。
  final bool allergy;
  final List<FeedRecord> records;
  final Catalog catalog;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = Day.of(TimeRules.now()) == day;
    final rows = cellRows(records.length);
    final base = Theme.of(context).textTheme.labelSmall!.copyWith(fontSize: 11, color: c.text);
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: allergy ? c.danger.withValues(alpha: 0.16) : null,
          border: Border.all(color: c.border, width: 0.25),
        ),
        padding: const EdgeInsets.fromLTRB(1, 3, 1, 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: today ? BoxDecoration(color: c.todayBg, shape: BoxShape.circle) : null,
              child: Text('${day.day}',
                  style: weight(Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 12, color: today ? c.todayText : c.text2),
                      today ? 700 : 400)),
            ),
          ),
          const SizedBox(height: 2),
          for (var i = 0; i < rows.shown; i++) _entry(context, records[i], base),
          if (rows.more) _line(context, '…', base),
        ]),
      ),
    );
  }

  Widget _entry(BuildContext context, FeedRecord r, TextStyle style) {
    final food = catalog.food(r.foodId);
    return _line(context, '${food?.emoji ?? ''}${food?.name ?? ''}', style);
  }

  /// 每排「emoji + 食材名稱」,太寬或格子不夠高(小螢幕、系統字型調大)時自動縮小到放得下為止。
  /// Flexible:三排平分日期下方的高度,放得下就用原本的大小,放不下才縮(不撐高、不爆版)。
  Widget _line(BuildContext context, String text, TextStyle style) => Flexible(
        child: Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: context.colors.entryBg, borderRadius: BorderRadius.circular(Radii.entry)),
          child: Align(
            alignment: Alignment.centerLeft,
            heightFactor: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(text, maxLines: 1, softWrap: false, style: style),
            ),
          ),
        ),
      );
}
