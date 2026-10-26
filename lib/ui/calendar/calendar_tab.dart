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

class _CalendarTabState extends ConsumerState<CalendarTab> with SingleTickerProviderStateMixin {
  late int _year;
  late int _month;

  /// 月份目前被拖開多少(像素):正 = 往右拖(露出上個月),負 = 往左拖(露出下個月)。
  late final AnimationController _offset = AnimationController.unbounded(vsync: this);
  double _width = 1;

  @override
  void initState() {
    super.initState();
    final today = Day.of(TimeRules.now());
    _year = today.year.clamp(Limits.yearMin, Limits.yearMax);
    _month = today.month;
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  bool get _atStart => _year == Limits.yearMin && _month == 1;

  bool get _atEnd => _year == Limits.yearMax && _month == 12;

  (int, int) _neighbor(int delta) {
    final m = DateTime.utc(_year, _month + delta);
    return (m.year, m.month);
  }

  /// 換月:這個月滑出去、旁邊的月份滑進來,滑完才真的換。年月選單跳月不用動畫。
  Future<void> _shift(int delta) async {
    if ((delta < 0 && _atStart) || (delta > 0 && _atEnd) || _offset.isAnimating) return;
    await _offset.animateTo(-delta * _width, duration: Timing.monthSlide, curve: Curves.easeOutCubic);
    if (!mounted) return;
    final (year, month) = _neighbor(delta);
    setState(() {
      _year = year;
      _month = month;
    });
    _offset.value = 0;
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (_offset.isAnimating) return;
    var next = _offset.value + d.delta.dx;
    // 第一個月不能再往前、最後一個月不能再往後:往那邊拖只給一點點阻力,不露出不存在的月份。
    if ((next > 0 && _atStart) || (next < 0 && _atEnd)) next = (next * 0.15).clamp(-24.0, 24.0);
    _offset.value = next.clamp(-_width, _width);
  }

  void _dragEnd() {
    if (_offset.isAnimating) return;
    final threshold = _width * Timing.monthSwipeFraction;
    if (_offset.value <= -threshold && !_atEnd) {
      _shift(1);
    } else if (_offset.value >= threshold && !_atStart) {
      _shift(-1);
    } else {
      _offset.animateTo(0, duration: Timing.monthSlide, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baby = ref.watch(currentBabyProvider);
    final catalog = ref.watch(catalogProvider).value;
    final settings = settingsOf(ref);
    if (baby == null || catalog == null) return const SizedBox.shrink();
    final c = context.colors;
    Widget grid(int year, int month) => _MonthGrid(
          key: ValueKey('$year-$month'),
          babySeq: baby.seq,
          year: year,
          month: month,
          catalog: catalog,
          weekStartsMonday: settings.weekStartsMonday,
          onOpenDay: (day, records) => _openDay(context, baby.seq, day, records),
        );
    return LayoutBuilder(builder: (context, constraints) {
      _width = constraints.maxWidth;
      return GestureDetector(
        // 左右滑動換月:月份跟著手指移動,放手時拖超過一半寬度才換(只看距離,不看甩動速度),
        // 換的時候這個月滑走、旁邊的月份滑進來;不到一半就滑回原位。
        onHorizontalDragUpdate: _dragUpdate,
        onHorizontalDragEnd: (_) => _dragEnd(),
        onHorizontalDragCancel: _dragEnd,
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
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _offset,
                builder: (context, _) {
                  final dx = _offset.value;
                  // 往左拖露出下個月(在右邊),往右拖露出上個月(在左邊)。
                  final neighbor = dx < 0 && !_atEnd
                      ? _neighbor(1)
                      : dx > 0 && !_atStart
                          ? _neighbor(-1)
                          : null;
                  return Stack(children: [
                    if (neighbor != null)
                      Positioned.fill(
                        child: Transform.translate(
                          offset: Offset(dx < 0 ? dx + _width : dx - _width, 0),
                          child: grid(neighbor.$1, neighbor.$2),
                        ),
                      ),
                    Positioned.fill(child: Transform.translate(offset: Offset(dx, 0), child: grid(_year, _month))),
                  ]);
                },
              ),
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

/// 一個月的格子。換月動畫時,這個月與旁邊的月份各一份。
class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({
    super.key,
    required this.babySeq,
    required this.year,
    required this.month,
    required this.catalog,
    required this.weekStartsMonday,
    required this.onOpenDay,
  });

  final int babySeq;
  final int year;
  final int month;
  final Catalog catalog;
  final bool weekStartsMonday;
  final void Function(Day day, List<FeedRecord> records) onOpenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = knownOnly(ref.watch(monthRecordsProvider((babySeq, year, month))).value ?? const [], catalog);
    // 上個月最後一天填了「隔天發生過敏」的話,這個月 1 號也要標。
    final prevMonth = Day(year, month, 1).addDays(-1);
    final prevRecords =
        knownOnly(ref.watch(monthRecordsProvider((babySeq, prevMonth.year, prevMonth.month))).value ?? const [], catalog);
    final allergyDays = allergyMarkedDays([...records, ...prevRecords.where((r) => r.day == prevMonth)]);
    final digestiveDays = digestiveMarkedDays(records);
    final byDay = <Day, List<FeedRecord>>{};
    for (final r in records) {
      byDay.putIfAbsent(r.day, () => []).add(r);
    }
    final c = context.colors;
    return Container(
      color: c.bg,
      child: Column(children: [
        for (final week in monthGrid(year, month, weekStartsMonday: weekStartsMonday))
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
                          mark: switch ((allergyDays.contains(day), digestiveDays.contains(day))) {
                            (true, true) => _DayMark.both,
                            (true, false) => _DayMark.allergy,
                            (false, true) => _DayMark.digestive,
                            (false, false) => null,
                          },
                          onTap: () => onOpenDay(day, byDay[day] ?? const []),
                        ),
                ),
            ]),
          ),
      ]),
    );
  }
}

/// 月曆格子的底色(SPEC 第 14 節):過敏淡紅、腹瀉或嘔吐淡黃、同一天兩種都有淡紫。
enum _DayMark { allergy, digestive, both }

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.records, required this.catalog, required this.mark, required this.onTap});

  final Day day;

  /// 格子底色:過敏(當天過敏的那天、隔天過敏的下一天)、腹瀉或嘔吐、兩種都有;null = 不標。
  final _DayMark? mark;
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
          color: switch (mark) {
            _DayMark.allergy => c.danger.withValues(alpha: 0.16),
            _DayMark.digestive => c.warn.withValues(alpha: 0.22),
            // 紫色不在主題色裡:淺色、深色模式都用同一個紫,透明度調到兩邊都看得出來。
            _DayMark.both => const Color(0xFF9B6BD6).withValues(alpha: 0.24),
            null => null,
          },
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
