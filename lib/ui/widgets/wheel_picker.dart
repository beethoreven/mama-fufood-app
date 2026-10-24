import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../theme.dart';

/// 捲動選單(SPEC 第 6 節):
/// - 捲動停止 1 秒後自動套用並關閉(Timing.pickerAutoApply)。
/// - 自動套用前點選單外面:關閉選單、當作沒開過(維持原值,回傳 null)。
/// - 點某一項會捲到那一項,同樣停 1 秒後套用。
Future<T?> showWheelPicker<T>(
  BuildContext context, {
  required List<T> items,
  required T? initial,
  required String Function(T) label,
  String? title,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _WheelPickerDialog<T>(items: items, initial: initial, label: label, title: title),
  );
}

class _WheelPickerDialog<T> extends StatefulWidget {
  const _WheelPickerDialog({required this.items, required this.initial, required this.label, this.title});

  final List<T> items;
  final T? initial;
  final String Function(T) label;
  final String? title;

  @override
  State<_WheelPickerDialog<T>> createState() => _WheelPickerDialogState<T>();
}

class _WheelPickerDialogState<T> extends State<_WheelPickerDialog<T>> {
  late final FixedExtentScrollController _controller;
  Timer? _timer;
  late int _index;

  static const _itemExtent = 48.0;

  @override
  void initState() {
    super.initState();
    final i = widget.initial == null ? -1 : widget.items.indexOf(widget.initial as T);
    _index = i < 0 ? 0 : i;
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleApply() {
    _timer?.cancel();
    _timer = Timer(Timing.pickerAutoApply, () {
      if (mounted) Navigator.of(context).pop(widget.items[_index]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final visible = widget.items.length < 5 ? widget.items.length : 5;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(widget.title!, style: Theme.of(context).textTheme.titleSmall),
              ),
            Text('停 1 秒自動選定，點外面取消', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: _itemExtent * (visible < 3 ? 3 : visible),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      height: _itemExtent,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                  NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollStartNotification) _timer?.cancel();
                      if (n is ScrollEndNotification) _scheduleApply();
                      return false;
                    },
                    child: ListWheelScrollView.useDelegate(
                      controller: _controller,
                      itemExtent: _itemExtent,
                      physics: const FixedExtentScrollPhysics(),
                      diameterRatio: 1.6,
                      onSelectedItemChanged: (i) => _index = i,
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: widget.items.length,
                        builder: (context, i) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (i == _index) {
                              _scheduleApply();
                            } else {
                              _controller.animateToItem(i,
                                  duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                            }
                          },
                          child: Center(
                            child: Text(widget.label(widget.items[i]),
                                style: Theme.of(context).textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 年月選擇鈕(膠囊形、次要底色)。
class PickerButton extends StatelessWidget {
  const PickerButton({super.key, required this.text, required this.onTap, this.enabled = true});

  final String text;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: enabled ? c.surface2 : c.surface2.withValues(alpha: 0.4),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          // 觸控目標至少 48 dp(SPEC 第 1 節;test/ui/layout/ 會檢查)。
          constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(text,
                      overflow: TextOverflow.ellipsis,
                      style: weight(Theme.of(context).textTheme.bodyLarge!.copyWith(color: enabled ? c.text : c.muted), 500)),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more_rounded, size: 18, color: enabled ? c.text2 : c.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
