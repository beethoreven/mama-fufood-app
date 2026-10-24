import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/text.dart';
import '../../core/time.dart';
import '../../domain/stats.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/wheel_picker.dart';

/// 頁籤 2:統計(SPEC 第 7 節)。篩選:年必選(不可「不指定」)、月預設「不指定」、
/// 日鎖定直到選了月。結果只加總「食用量」。
class StatsTab extends ConsumerStatefulWidget {
  const StatsTab({super.key});

  @override
  ConsumerState<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends ConsumerState<StatsTab> {
  late int _year;
  int? _month;
  int? _day;

  @override
  void initState() {
    super.initState();
    _year = TimeRules.now().year.clamp(Limits.yearMin, Limits.yearMax);
  }

  @override
  Widget build(BuildContext context) {
    final baby = ref.watch(currentBabyProvider);
    final catalog = ref.watch(catalogProvider).value;
    if (baby == null || catalog == null) return const SizedBox.shrink();
    final async = ref.watch(allRecordsProvider(baby.seq));
    final records = async.value ?? const [];
    final stats = computeStats(records, catalog, StatsFilter(year: _year, month: _month, day: _day));
    final c = context.colors;
    final daysInMonth = _month == null ? 31 : DateTime.utc(_year, _month! + 1, 0).day;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        color: c.surface,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          PickerButton(
            text: '$_year 年',
            onTap: () async {
              final y = await showWheelPicker<int>(context,
                  title: '年', items: [for (var y = Limits.yearMin; y <= Limits.yearMax; y++) y], initial: _year, label: (y) => '$y 年');
              if (y != null) setState(() => _year = y);
            },
          ),
          PickerButton(
            text: _month == null ? '月:不指定' : '$_month 月',
            onTap: () async {
              final m = await showWheelPicker<int>(context,
                  title: '月', items: [0, for (var m = 1; m <= 12; m++) m], initial: _month ?? 0, label: (m) => m == 0 ? '不指定' : '$m 月');
              if (m != null) {
                setState(() {
                  _month = m == 0 ? null : m;
                  if (_month == null) _day = null;
                  if (_day != null && _month != null && _day! > DateTime.utc(_year, _month! + 1, 0).day) _day = null;
                });
              }
            },
          ),
          PickerButton(
            enabled: _month != null,
            text: _day == null ? '日:不指定' : '$_day 日',
            onTap: () async {
              final d = await showWheelPicker<int>(context,
                  title: '日', items: [0, for (var d = 1; d <= daysInMonth; d++) d], initial: _day ?? 0, label: (d) => d == 0 ? '不指定' : '$d 日');
              if (d != null) setState(() => _day = d == 0 ? null : d);
            },
          ),
        ]),
      ),
      Expanded(
        child: async.hasError
            ? Center(child: Text('讀取紀錄失敗,請重新開啟 App', style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: c.danger)))
            : !async.hasValue
            ? const Center(child: CircularProgressIndicator())
            : stats.isEmpty
            ? Center(child: Text('這段期間沒有紀錄', style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: c.text2)))
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                children: [
                  for (final g in stats) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                      child: Text('${g.group.emoji} ${g.group.name}', style: Theme.of(context).textTheme.titleSmall),
                    ),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Column(children: [
                        for (final f in g.foods)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(f.food.emoji, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 64,
                                child: Text(f.food.name, style: weight(Theme.of(context).textTheme.bodyLarge!, 500)),
                              ),
                              Expanded(
                                // 單位最多可能排成兩行。
                                child: Wrap(spacing: 10, runSpacing: 2, alignment: WrapAlignment.end, children: [
                                  if (f.refused)
                                    Text('寶寶不吃', style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: c.text2))
                                  else
                                    for (final e in visibleUnitTotals(f, catalog))
                                      Text('${Amount.format(e.value)} ${e.key.name}', style: Theme.of(context).textTheme.bodyMedium),
                                ]),
                              ),
                            ]),
                          ),
                      ]),
                    ),
                  ],
                  const DisclaimerText(Disclaimers.stats),
                ],
              ),
      ),
      if (stats.isEmpty) const DisclaimerText(Disclaimers.stats),
    ]);
  }
}
