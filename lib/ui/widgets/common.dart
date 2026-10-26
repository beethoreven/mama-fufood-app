import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../domain/judgement.dart';
import '../../domain/record.dart';
import '../theme.dart';

/// 免責小字(texts/DISCLAIMERS_DRAFT.md 第一節)。月曆頁因版面空間不放,其他頁面都放;
/// 小對話框與提示訊息不放。
abstract final class Disclaimers {
  static const record = '本 App 僅供記錄與參考，非基於醫學知識做的判斷。任何反應請諮詢醫師。';
  static const stats = '統計只加總你記錄的食用量，僅供記錄與參考。';
  static const judgement = '僅供記錄與參考，非基於醫學知識做的判斷；沒有圖示代表紀錄還不夠。任何反應請諮詢醫師。';
  static const guide = '本 App 僅供記錄與參考，非基於醫學知識做的判斷。寶寶有任何反應，請諮詢醫師。';
  static const general = '本 App 僅供記錄與參考，非基於醫學知識做的判斷。';
}

class DisclaimerText extends StatelessWidget {
  const DisclaimerText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
      );
}

/// 判斷圖示(DESIGN_SYSTEM.md「判斷圖示」):不能只靠顏色,一定搭配不同的圖示和文字。
/// 「紀錄不足」不放圖示、位置留空。
class AllergyIcon extends StatelessWidget {
  const AllergyIcon(this.level, {super.key, this.size = 26});

  final AllergyLevel? level;
  final double size;

  static String label(AllergyLevel l) => switch (l) {
        AllergyLevel.stable => '穩定',
        AllergyLevel.risk => '風險',
        AllergyLevel.allergic => '過敏',
      };

  static String explain(AllergyLevel l) => switch (l) {
        AllergyLevel.stable => '目前的紀錄沒有出現過敏狀況。這不代表這個食材是安全的。',
        AllergyLevel.risk => '紀錄中出現過過敏狀況，請留意寶寶的反應，有疑慮請諮詢醫師。',
        AllergyLevel.allergic => '多次出現過敏反應，建議諮詢醫師。',
      };

  @override
  Widget build(BuildContext context) {
    final l = level;
    if (l == null) return SizedBox(width: size + 8, height: size + 8);
    final c = context.colors;
    final (icon, color) = switch (l) {
      AllergyLevel.stable => (Symbols.verified_rounded, c.ok),
      AllergyLevel.risk => (Symbols.warning_rounded, c.warn),
      AllergyLevel.allergic => (Symbols.error_rounded, c.danger),
    };
    return InfoPopover(
      message: '過敏狀況：${label(l)}\n${explain(l)}\n\n$_tail',
      child: Semantics(
        label: '過敏狀況${label(l)}',
        child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, fill: 1, color: color, size: size)),
      ),
    );
  }
}

class PreferenceIcon extends StatelessWidget {
  const PreferenceIcon(this.level, {super.key, this.size = 26});

  final PreferenceLevel? level;
  final double size;

  static String label(PreferenceLevel l) => switch (l) {
        PreferenceLevel.reject => '排斥',
        PreferenceLevel.accept => '接受',
        PreferenceLevel.like => '喜歡',
      };

  static String explain(PreferenceLevel l) => switch (l) {
        PreferenceLevel.reject => '依最近的紀錄，寶寶大多不太接受這個食材。口味會隨多次嘗試改變。',
        PreferenceLevel.accept => '依最近的紀錄，寶寶大多可以接受這個食材。',
        PreferenceLevel.like => '依最近的紀錄，寶寶大多喜歡這個食材。',
      };

  @override
  Widget build(BuildContext context) {
    final l = level;
    if (l == null) return SizedBox(width: size + 8, height: size + 8);
    final c = context.colors;
    final (icon, color) = switch (l) {
      PreferenceLevel.reject => (Symbols.sentiment_dissatisfied_rounded, c.reject),
      PreferenceLevel.accept => (Symbols.sentiment_neutral_rounded, c.accept),
      PreferenceLevel.like => (Symbols.sentiment_very_satisfied_rounded, c.like),
    };
    return InfoPopover(
      message: '用食反應：${label(l)}\n${explain(l)}\n\n$_tail',
      child: Semantics(
        label: '用食反應${label(l)}',
        child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, fill: 1, color: color, size: size)),
      ),
    );
  }
}

/// 腹瀉或嘔吐的圖示(頁籤 4)。只有兩個等級:正常、有發生。「紀錄不足」不放圖示、位置留空。
enum DigestiveKind { diarrhea, vomiting }

class DigestiveIcon extends StatelessWidget {
  const DigestiveIcon(this.kind, this.level, {super.key, this.size = 26});

  final DigestiveKind kind;
  final DigestiveLevel? level;
  final double size;

  String get _name => kind == DigestiveKind.diarrhea ? '腹瀉' : '嘔吐';

  String label(DigestiveLevel l) => l == DigestiveLevel.normal ? '正常' : _name;

  String explain(DigestiveLevel l) => l == DigestiveLevel.normal
      ? '目前的紀錄裡，吃這個食材之後大多沒有$_name。這不代表這個食材不會造成$_name。'
      : '紀錄裡吃這個食材之後常出現$_name，請留意寶寶的狀況，有疑慮請諮詢醫師。';

  @override
  Widget build(BuildContext context) {
    final l = level;
    if (l == null) return SizedBox(width: size + 8, height: size + 8);
    final c = context.colors;
    final (icon, color) = l == DigestiveLevel.normal
        ? (Symbols.check_circle_rounded, c.ok)
        : (kind == DigestiveKind.diarrhea ? Symbols.water_drop_rounded : Symbols.sick_rounded, c.warn);
    return InfoPopover(
      message: '$_name：${label(l)}\n${explain(l)}\n\n$_tail',
      child: Semantics(
        label: '$_name${label(l)}',
        child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, fill: 1, color: color, size: size)),
      ),
    );
  }
}

const _tail = '僅供記錄與參考，非基於醫學知識做的判斷；判斷方式見「判斷邏輯說明」。';

/// 輕點出現說明文字,點其他地方或滑動就消失(SPEC 第 7 節)。
class InfoPopover extends StatefulWidget {
  const InfoPopover({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  State<InfoPopover> createState() => _InfoPopoverState();
}

class _InfoPopoverState extends State<InfoPopover> {
  final _controller = OverlayPortalController();
  final _link = LayerLink();
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.removeListener(_hide);
    _position = Scrollable.maybeOf(context)?.position;
    _position?.addListener(_hide);
  }

  @override
  void dispose() {
    _position?.removeListener(_hide);
    super.dispose();
  }

  void _hide() {
    if (_controller.isShowing) _controller.hide();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (_) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (_) => _hide(),
                onPanStart: (_) => _hide(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 4),
              child: Material(
                color: c.surface2,
                elevation: 4,
                borderRadius: BorderRadius.circular(14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(widget.message, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: c.text)),
                  ),
                ),
              ),
            ),
          ],
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _controller.isShowing ? _controller.hide() : _controller.show(),
          // 圖示本身比較小,點的範圍至少 48 dp(觸控目標的規定)。
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(widthFactor: 1, heightFactor: 1, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// 在畫面下方顯示一則提示(toast)。
void toast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
}

/// 二次確認。
Future<bool> confirm(BuildContext context,
    {required String title, required String message, String ok = '確定', bool danger = false}) async {
  final c = context.colors;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: c.danger, foregroundColor: c.bg) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 卡片(圓角 20 dp、內距 12 dp)。
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(12)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: padding, child: child));
}

/// 膠囊形的單選選項(選中:選中底色 + 主色外框 + 打勾)。再點一次取消。
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips(
      {super.key, required this.options, required this.value, required this.label, required this.onChanged, this.readOnly = false});

  final List<T> options;
  final T? value;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;

  /// 只能看:不能點,字與選中的框線都用灰色,看起來是鎖住的。
  final bool readOnly;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options)
          SelectChip(
            label: label(o),
            selected: o == value,
            readOnly: readOnly,
            onTap: () => onChanged(o == value ? null : o),
          ),
      ]);
}

/// 「腹瀉或嘔吐」的選項(SPEC 第 14 節):正常／腹瀉／嘔吐。
/// 選了「正常」時另外兩個點了沒反應;選了腹瀉或嘔吐時「正常」點了沒反應;腹瀉、嘔吐可以同時選。
/// 再點一次已選的就取消;全部取消 = 沒填。
class DigestiveChips extends StatelessWidget {
  const DigestiveChips({super.key, required this.value, required this.onChanged, this.readOnly = false});

  final Digestive? value;
  final ValueChanged<Digestive?> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final normal = v == Digestive.normal;
    final diarrhea = v?.hasDiarrhea ?? false;
    final vomiting = v?.hasVomiting ?? false;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      SelectChip(
        label: '正常',
        selected: normal,
        readOnly: readOnly,
        onTap: diarrhea || vomiting ? null : () => onChanged(normal ? null : Digestive.normal),
      ),
      SelectChip(
        label: '腹瀉',
        selected: diarrhea,
        readOnly: readOnly,
        onTap: normal ? null : () => onChanged(Digestive.fromFlags(diarrhea: !diarrhea, vomiting: vomiting)),
      ),
      SelectChip(
        label: '嘔吐',
        selected: vomiting,
        readOnly: readOnly,
        onTap: normal ? null : () => onChanged(Digestive.fromFlags(diarrhea: diarrhea, vomiting: !vomiting)),
      ),
    ]);
  }
}

/// 選項膠囊。onTap 是 null 時點了沒反應(外觀不變)。
class SelectChip extends StatelessWidget {
  const SelectChip({super.key, required this.label, required this.selected, required this.onTap, this.readOnly = false});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// 只能看:不能點,字與選中的框線都用灰色,看起來是鎖住的。
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mark = readOnly ? c.muted : c.accent;
    return Material(
      color: selected && !readOnly ? c.accentSoft : c.surface2,
      shape: StadiumBorder(side: BorderSide(color: selected ? mark : Colors.transparent, width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: readOnly ? null : onTap,
        child: ConstrainedBox(
          // 觸控目標至少 48 dp(SPEC 第 1 節;test/ui/layout/ 會檢查)。
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (selected) ...[Icon(Icons.check_rounded, size: 18, color: mark), const SizedBox(width: 4)],
              Text(label,
                  style: readOnly
                      ? Theme.of(context).textTheme.labelMedium!.copyWith(color: c.muted)
                      : Theme.of(context).textTheme.labelMedium),
            ]),
          ),
        ),
      ),
    );
  }
}
