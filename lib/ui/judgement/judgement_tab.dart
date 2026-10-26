import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time.dart';
import '../../domain/catalog.dart';
import '../../domain/judgement.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/wheel_picker.dart';

/// 頁籤 3「食材判斷」與頁籤 4「腹瀉嘔吐」(SPEC 第 7 節、第 14 節)。兩頁版面一樣:
/// 篩選分組、食材(食材須先選分組,可只選分組),列出所選分組的全部食材,各附兩個圖示——
/// 頁籤 3 是喜好與過敏,頁籤 4 是腹瀉與嘔吐;紀錄不足的位置留空。
class JudgementTab extends ConsumerStatefulWidget {
  const JudgementTab({super.key, this.digestive = false});

  /// true = 頁籤 4「腹瀉嘔吐」。
  final bool digestive;

  @override
  ConsumerState<JudgementTab> createState() => _JudgementTabState();
}

class _JudgementTabState extends ConsumerState<JudgementTab> {
  int? _groupId;
  int? _foodId;

  @override
  Widget build(BuildContext context) {
    final baby = ref.watch(currentBabyProvider);
    final catalog = ref.watch(catalogProvider).value;
    if (baby == null || catalog == null) return const SizedBox.shrink();
    final groups = catalog.groups.where((g) => !g.disabled || _groupId == g.id).toList();
    final groupId = _groupId ?? (groups.isEmpty ? null : groups.first.id);
    final group = groupId == null ? null : catalog.group(groupId);
    final foods = groupId == null ? <Food>[] : catalog.foodsInGroup(groupId);
    final shown = _foodId == null ? foods.where((f) => !f.disabled).toList() : foods.where((f) => f.id == _foodId).toList();
    final async = ref.watch(allRecordsProvider(baby.seq));
    if (async.hasError) {
      return Center(child: Text('讀取紀錄失敗，請重新開啟 App', style: TextStyle(color: context.colors.danger)));
    }
    if (!async.hasValue) return const Center(child: CircularProgressIndicator());
    final records = knownOnly(async.value!, catalog);
    final today = Day.of(TimeRules.now());
    final c = context.colors;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        color: c.surface,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          PickerButton(
            text: group == null ? '選分組' : '${group.emoji} ${group.name}',
            onTap: () async {
              final g = await showWheelPicker<FoodGroup>(context,
                  title: '分組', items: groups, initial: group, label: (g) => '${g.emoji} ${g.name}');
              if (g != null) {
                setState(() {
                  _groupId = g.id;
                  _foodId = null;
                });
              }
            },
          ),
          PickerButton(
            enabled: group != null,
            text: _foodId == null ? '食材：全部' : '${catalog.food(_foodId!)?.emoji} ${catalog.food(_foodId!)?.name}',
            onTap: () async {
              // 0 代表「全部」;點外面取消時回 null,維持原本的選擇。
              final options = [0, for (final f in foods.where((f) => !f.disabled)) f.id];
              final id = await showWheelPicker<int>(context,
                  title: '食材',
                  items: options,
                  initial: _foodId ?? 0,
                  label: (id) => id == 0 ? '全部' : '${catalog.food(id)?.emoji} ${catalog.food(id)?.name}');
              if (id != null) setState(() => _foodId = id == 0 ? null : id);
            },
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
        child: Row(children: [
          const Spacer(),
          for (final title in widget.digestive ? const ['腹瀉', '嘔吐'] : const ['喜好', '過敏'])
            SizedBox(width: 56, child: Center(child: Text(title, style: Theme.of(context).textTheme.labelSmall))),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Column(children: [
                for (final f in shown)
                  Builder(builder: (context) {
                    final mine = records.where((r) => r.foodId == f.id).toList();
                    final digestive = widget.digestive ? judgeDigestive(mine) : null;
                    return SizedBox(
                      height: 52,
                      child: Row(children: [
                        Text(f.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(f.name, style: weight(Theme.of(context).textTheme.bodyLarge!, 500))),
                        if (digestive != null) ...[
                          SizedBox(width: 56, child: Center(child: DigestiveIcon(DigestiveKind.diarrhea, digestive.diarrhea))),
                          SizedBox(width: 56, child: Center(child: DigestiveIcon(DigestiveKind.vomiting, digestive.vomiting))),
                        ] else ...[
                          SizedBox(width: 56, child: Center(child: PreferenceIcon(judgePreference(mine, today: today)))),
                          SizedBox(width: 56, child: Center(child: AllergyIcon(judgeAllergy(mine)))),
                        ],
                      ]),
                    );
                  }),
              ]),
            ),
            const DisclaimerText(Disclaimers.judgement),
          ],
        ),
      ),
    ]);
  }
}
