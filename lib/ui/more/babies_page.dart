import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/store.dart';
import '../../state/providers.dart';
import '../flows.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 寶寶們設定(新增、改名、刪除)。名稱最多 20 字、不可重複、最多 8 個寶寶(SPEC 第 5 節)。
class BabiesPage extends ConsumerWidget {
  const BabiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final babies = ref.watch(babiesProvider).value ?? const <Baby>[];
    final store = ref.watch(storeProvider);
    final c = context.colors;
    return ListView(padding: const EdgeInsets.all(12), children: [
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          for (final b in babies)
            ListTile(
              leading: CircleAvatar(backgroundColor: c.accentSoft, child: Text('${b.seq}', style: TextStyle(color: c.text))),
              title: Text(b.name),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: '改名',
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () async {
                    final name = await askBabyName(context, title: '改名', initial: b.name);
                    if (name == null) return;
                    try {
                      await store.renameBaby(b.seq, name);
                      ref.read(servicesProvider).sync.requestSoon();
                    } on InputProblem catch (e) {
                      if (context.mounted) toast(context, e.message);
                    }
                  },
                ),
                IconButton(
                  tooltip: '刪除',
                  icon: Icon(Icons.delete_outline_rounded, color: c.danger),
                  onPressed: () => deleteBabyFlow(context, ref, b),
                ),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: babies.length >= Limits.maxBabies
            ? null
            : () async {
                final name = await askBabyName(context, title: '新增寶寶');
                if (name == null) return;
                try {
                  final baby = await store.addBaby(name);
                  await store.setSetting(Keys.currentBaby, '${baby.seq}');
                  ref.read(servicesProvider).sync.requestSoon();
                } on InputProblem catch (e) {
                  if (context.mounted) toast(context, e.message);
                }
              },
        icon: const Icon(Icons.add_rounded),
        label: Text(babies.length >= Limits.maxBabies ? '最多 ${Limits.maxBabies} 個寶寶' : '新增寶寶'),
      ),
      const SizedBox(height: 8),
      Text('改了寶寶的名稱,就會被當成不同的寶寶(匯入時用名稱比對)。', style: Theme.of(context).textTheme.labelSmall),
      const DisclaimerText(Disclaimers.general),
    ]);
  }
}

/// 輸入寶寶名稱。dismissible = false 時關不掉(第一次開啟、刪光寶寶之後)。
Future<String?> askBabyName(BuildContext context, {required String title, String initial = '', bool dismissible = true, String? help}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    barrierDismissible: dismissible,
    builder: (ctx) => PopScope(
      canPop: dismissible,
      child: AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (help != null) ...[Text(help), const SizedBox(height: 12)],
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: Limits.babyNameMaxChars,
            decoration: const InputDecoration(hintText: '本名或乳名都可以'),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
            },
          ),
        ]),
        actions: [
          if (dismissible) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('確定'),
          ),
        ],
      ),
    ),
  );
}
