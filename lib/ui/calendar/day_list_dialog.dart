import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/time.dart';
import '../../domain/record.dart';
import '../../state/providers.dart';
import '../record/record_dialog.dart';
import '../theme.dart';

/// 點有紀錄的日子 → 置中小清單(食材圖示 + 名稱,依時間由早到晚,最下面固定「新增」;
/// 已滿 10 筆則沒有「新增」;一欄放不下時改成兩欄;清單區可捲動)。SPEC 第 7 節。
Future<void> showDayListDialog(BuildContext context, {required int babySeq, required Day day}) =>
    showDialog(context: context, builder: (_) => _DayListDialog(babySeq: babySeq, day: day));

class _DayListDialog extends ConsumerWidget {
  const _DayListDialog({required this.babySeq, required this.day});

  final int babySeq;
  final Day day;

  static const _rowHeight = 52.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider).value;
    final records = catalog == null
        ? const <FeedRecord>[]
        : knownOnly(ref.watch(dayRecordsProvider((babySeq, day))).value ?? const [], catalog);
    final full = (ref.watch(dayRecordsProvider((babySeq, day))).value ?? const []).length >= Limits.recordsPerDay;
    final c = context.colors;
    final items = <Widget>[
      for (final r in records)
        _Item(
          icon: catalog?.food(r.foodId)?.emoji ?? '',
          text: catalog?.food(r.foodId)?.name ?? '',
          sub: '${r.localTime.hour.toString().padLeft(2, '0')}:${r.localTime.minute.toString().padLeft(2, '0')}',
          onTap: () async {
            await showRecordDialog(context, babySeq: babySeq, day: day, recordId: r.id);
          },
        ),
      if (!full)
        _Item(
          icon: '+',
          text: '新增',
          accent: true,
          onTap: () async {
            await showRecordDialog(context, babySeq: babySeq, day: day);
          },
        ),
    ];
    if (records.isEmpty && catalog != null && ref.watch(dayRecordsProvider((babySeq, day))).hasValue) {
      // 最後一筆刪掉之後就關掉清單。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final route = context.mounted ? ModalRoute.of(context) : null;
        if (route != null && route.isCurrent) Navigator.of(context).pop();
      });
    }
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${day.month} 月 ${day.day} 日', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Flexible(
            child: LayoutBuilder(builder: (context, constraints) {
              final oneColumnHeight = items.length * _rowHeight;
              final twoColumns = constraints.maxHeight.isFinite && oneColumnHeight > constraints.maxHeight;
              if (!twoColumns) {
                return ListView(shrinkWrap: true, children: items);
              }
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                childAspectRatio: (constraints.maxWidth / 2) / _rowHeight,
                children: items,
              );
            }),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => Navigator.pop(context), child: Text('關閉', style: TextStyle(color: c.text2))),
          ),
        ]),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.text, required this.onTap, this.sub, this.accent = false});

  final String icon;
  final String text;
  final String? sub;
  final bool accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: accent ? c.accent : c.entryBg, shape: BoxShape.circle),
            child: Text(icon, style: TextStyle(fontSize: accent ? 20 : 18, color: accent ? c.onAccent : null)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: weight(Theme.of(context).textTheme.bodyLarge!.copyWith(color: accent ? c.accent : c.text), 500)),
          ),
          if (sub != null) Text(sub!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 6),
        ]),
      ),
    );
  }
}
