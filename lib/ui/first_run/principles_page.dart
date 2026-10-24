import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../core/log.dart';
import '../theme.dart';

/// 第一次開啟時的「資料運用原則」(SPEC 第 5 節):必須捲到最下面,「我了解了」才能按;
/// 這個頁面關不掉。隱私權政策或使用者條款改版後第一次開啟,也會再顯示一次。
class PrinciplesPage extends StatefulWidget {
  const PrinciplesPage({super.key, required this.onAccepted, required this.isUpdate});

  final VoidCallback onAccepted;

  /// 改版後再顯示一次(文案稍微不同)。
  final bool isUpdate;

  @override
  State<PrinciplesPage> createState() => _PrinciplesPageState();
}

class _PrinciplesPageState extends State<PrinciplesPage> {
  final _scroll = ScrollController();
  bool _reachedEnd = false;
  String? _text;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/texts/data_principles.md').then((t) {
      if (!mounted) return;
      setState(() => _text = t);
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    });
    _scroll.addListener(_check);
  }

  void _check() {
    if (!_scroll.hasClients || _reachedEnd) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 8) setState(() => _reachedEnd = true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('資料運用原則', style: t.titleLarge),
                const SizedBox(height: 6),
                Text(widget.isUpdate ? '使用者條款或隱私權政策有更新,請看過更新後的內容。' : '開始使用前,請先看過我們怎麼處理你的資料。',
                    style: t.bodySmall),
              ]),
            ),
            Expanded(
              child: _text == null
                  ? const Center(child: CircularProgressIndicator())
                  : Scrollbar(
                      controller: _scroll,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: MarkdownBody(
                          data: _text!,
                          styleSheet: MarkdownStyleSheet(p: t.bodyMedium!.copyWith(height: 1.7), listBullet: t.bodyMedium),
                        ),
                      ),
                    ),
            ),
            Container(
              decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Column(children: [
                if (!_reachedEnd) Text('請捲到最下面', style: t.labelSmall),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _reachedEnd
                        ? () {
                            AppLog.info('policy.accepted', {'update': widget.isUpdate});
                            widget.onAccepted();
                          }
                        : null,
                    child: const Text('我了解了'),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
