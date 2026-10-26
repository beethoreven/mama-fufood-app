import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/log.dart';
import '../data/store.dart';
import '../services/auth_service.dart';
import '../state/providers.dart';
import 'calendar/calendar_tab.dart';
import 'flows.dart';
import 'judgement/judgement_tab.dart';
import 'more/babies_page.dart';
import 'more/feedback_page.dart';
import 'more/import_export_page.dart';
import 'more/settings_page.dart';
import 'more/text_pages.dart';
import 'stats/stats_tab.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// 更多選單的子頁面。
class SubPage {
  const SubPage(this.title, this.builder);

  final String title;
  final WidgetBuilder builder;
}

class ShellState {
  const ShellState({this.tab = 0, this.stack = const []});

  final int tab;
  final List<SubPage> stack;
}

class ShellController extends Notifier<ShellState> {
  @override
  ShellState build() => const ShellState();

  void selectTab(int tab) {
    AppLog.info('ui.tab', {'tab': tab});
    state = ShellState(tab: tab);
  }

  void push(SubPage page) {
    AppLog.info('ui.page', {'page': page.title.hashCode});
    state = ShellState(tab: state.tab, stack: [...state.stack, page]);
  }

  bool pop() {
    if (state.stack.isEmpty) return false;
    state = ShellState(tab: state.tab, stack: state.stack.sublist(0, state.stack.length - 1));
    return true;
  }
}

final shellProvider = NotifierProvider<ShellController, ShellState>(ShellController.new);

final authUserProvider = Provider<SignedInUser?>((ref) {
  final auth = ref.watch(servicesProvider).auth;
  void listener() => ref.invalidateSelf();
  auth.addListener(listener);
  ref.onDispose(() => auth.removeListener(listener));
  return auth.user;
});

/// 主畫面:頂部列與底部頁籤列在所有頁面與彈出介面下都固定不動(SPEC 第 6 節)。
/// 進入更多選單的子頁面時,頂部列左側換成返回箭頭加頁面標題,底部頁籤維持進入前亮著的那一個。
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _tabs = [
    (Symbols.calendar_month_rounded, '行事曆'),
    (Symbols.bar_chart_rounded, '統計'),
    (Symbols.fact_check_rounded, '食材判斷'),
    (Symbols.sick_rounded, '腹瀉嘔吐'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = ref.watch(shellProvider);
    final c = context.colors;
    final sub = shell.stack.isEmpty ? null : shell.stack.last;
    return PopScope(
      canPop: shell.stack.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(shellProvider.notifier).pop();
      },
      child: Scaffold(
        appBar: _TopBar(sub: sub),
        body: sub != null
            ? KeyedSubtree(key: ValueKey(shell.stack.length), child: sub.builder(context))
            : IndexedStack(
                index: shell.tab.clamp(0, 3),
                children: const [CalendarTab(), StatsTab(), JudgementTab(), JudgementTab(digestive: true)],
              ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: _TabItem(
                        icon: _tabs[i].$1,
                        label: _tabs[i].$2,
                        selected: i == shell.tab,
                        onTap: () => ref.read(shellProvider.notifier).selectTab(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.accent : c.text2;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: selected ? 28 : 22, color: color, fill: selected ? 1 : 0),
        const SizedBox(height: 2),
        Text(label,
            style: weight(Theme.of(context).textTheme.labelSmall!.copyWith(color: color, fontSize: 11), selected ? 500 : 400)),
      ],
    );
    return InkWell(onTap: onTap, child: Semantics(selected: selected, button: true, child: content));
  }
}

class _TopBar extends ConsumerWidget implements PreferredSizeWidget {
  const _TopBar({required this.sub});

  final SubPage? sub;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final baby = ref.watch(currentBabyProvider);
    final user = ref.watch(authUserProvider);
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: sub == null ? 14 : 0,
      leading: sub == null
          ? null
          : IconButton(
              tooltip: '返回',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => ref.read(shellProvider.notifier).pop(),
            ),
      title: sub != null
          ? Text(sub!.title)
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showBabySwitcher(context, ref),
              // 觸控目標至少 48 dp。
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Symbols.child_care_rounded, size: 20, color: c.deco),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('${baby?.name ?? ''}的副食品記錄', overflow: TextOverflow.ellipsis),
                  ),
                  Icon(Icons.expand_more_rounded, size: 20, color: c.text2),
                ]),
              ),
            ),
      actions: [
        _AccountButton(user: user),
        PopupMenuButton<int>(
          tooltip: '更多',
          icon: const Icon(Icons.more_vert_rounded),
          color: c.surface2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (i) => _openMore(ref, i),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 0, child: Text('App 設定')),
            PopupMenuItem(value: 1, child: Text('寶寶們設定')),
            PopupMenuItem(value: 2, child: Text('匯入/匯出')),
            PopupMenuItem(value: 3, child: Text('判斷邏輯說明')),
            PopupMenuItem(value: 4, child: Text('使用者條款')),
            PopupMenuItem(value: 5, child: Text('隱私權政策')),
            PopupMenuDivider(),
            PopupMenuItem(value: 6, child: Text('意見回饋')),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _openMore(WidgetRef ref, int i) {
    final shell = ref.read(shellProvider.notifier);
    final page = switch (i) {
      0 => SubPage('App 設定', (_) => const SettingsPage()),
      1 => SubPage('寶寶們設定', (_) => const BabiesPage()),
      2 => SubPage('匯入/匯出', (_) => const ImportExportPage()),
      3 => SubPage('判斷邏輯說明', (_) => const GuidePage()),
      4 => SubPage('使用者條款', (_) => const LegalPage(asset: 'terms')),
      5 => SubPage('隱私權政策', (_) => const LegalPage(asset: 'privacy')),
      _ => SubPage('意見回饋', (_) => const FeedbackPage()),
    };
    // 從某個子頁面再開另一個:直接換掉,不疊很多層。
    while (shell.pop()) {}
    shell.push(page);
  }

  Future<void> _showBabySwitcher(BuildContext context, WidgetRef ref) async {
    final babies = ref.read(babiesProvider).value ?? const <Baby>[];
    final current = ref.read(currentBabyProvider);
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final b in babies)
              ListTile(
                leading: Icon(b.seq == current?.seq ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: b.seq == current?.seq ? ctx.colors.accent : null),
                title: Text(b.name),
                onTap: () => Navigator.pop(ctx, b.seq),
              ),
            ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: const Text('寶寶們設定（新增、改名、刪除）'),
              onTap: () => Navigator.pop(ctx, -1),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    if (picked == -1) {
      _openMore(ref, 1);
      return;
    }
    await ref.read(storeProvider).setSetting(Keys.currentBaby, '$picked');
  }
}

/// 登入入口:頂部列右側、更多選單的左邊。沒登入是 Google 圖示,登入後換成頭像;
/// 點頭像顯示帳號 Email 與「登出」(SPEC 第 6 節)。
class _AccountButton extends ConsumerWidget {
  const _AccountButton({required this.user});

  final SignedInUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = user;
    final c = context.colors;
    if (u == null) {
      return IconButton(
        tooltip: '用 Google 帳號登入',
        icon: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: c.border)),
          child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        onPressed: () => signInFlow(context, ref),
      );
    }
    return IconButton(
      tooltip: u.email,
      icon: CircleAvatar(
        radius: 15,
        backgroundColor: c.accentSoft,
        foregroundImage: u.photoUrl == null ? null : NetworkImage(u.photoUrl!),
        child: Text(u.email.characters.first.toUpperCase(), style: TextStyle(color: c.text, fontSize: 14)),
      ),
      onPressed: () => showAccountSheet(context, ref, u),
    );
  }
}

Future<void> signInFlow(BuildContext context, WidgetRef ref) async {
  final services = ref.read(servicesProvider);
  try {
    await services.auth.signIn();
    if (context.mounted) await afterSignIn(context, services);
  } catch (e) {
    if (context.mounted) toast(context, _signInMessage(e));
  }
}

String _signInMessage(Object e) {
  final text = e.toString();
  if (text.contains('canceled')) return '已取消登入';
  if (text.contains('還沒設定')) return text.replaceFirst('Bad state: ', '');
  return '登入沒有成功，請稍後再試';
}

Future<void> showAccountSheet(BuildContext context, WidgetRef ref, SignedInUser u) async {
  final services = ref.read(servicesProvider);
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.account_circle_rounded), title: Text(u.name ?? u.email), subtitle: Text(u.email)),
        ListTile(
          leading: const Icon(Icons.logout_rounded),
          title: const Text('登出'),
          onTap: () => Navigator.pop(ctx, 'logout'),
        ),
      ]),
    ),
  );
  if (action != 'logout' || !context.mounted) return;
  await signOutFlow(context, services);
}
