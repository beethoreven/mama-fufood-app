import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// 內建在 App 裡的文字(texts/ 的草案,用 tools/sync_texts.py 同步進 assets/texts/)。
class MarkdownAsset extends StatefulWidget {
  const MarkdownAsset({super.key, required this.asset, this.header, this.footer});

  final String asset;
  final Widget? header;
  final Widget? footer;

  @override
  State<MarkdownAsset> createState() => _MarkdownAssetState();
}

class _MarkdownAssetState extends State<MarkdownAsset> {
  // 只載入一次:Future 寫在 build 裡的話,畫面每重建一次(例如打開選單)就重新載入、一直轉圈。
  late final Future<String> _text = rootBundle.loadString('assets/texts/${widget.asset}.md');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final header = widget.header;
    final footer = widget.footer;
    return FutureBuilder<String>(
      future: _text,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          ?header,
          MarkdownBody(
            data: snap.data!,
            styleSheet: MarkdownStyleSheet(
              h2: weight(t.titleMedium!, 500),
              h3: weight(t.titleSmall!, 500),
              p: t.bodyMedium!.copyWith(height: 1.6),
              listBullet: t.bodyMedium,
              tableBody: t.bodySmall!.copyWith(color: c.text),
              tableHead: weight(t.bodySmall!.copyWith(color: c.text), 500),
              tableBorder: TableBorder.all(color: c.border, width: 0.5),
              tableCellsPadding: const EdgeInsets.all(6),
              blockquoteDecoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
              blockquotePadding: const EdgeInsets.all(12),
              horizontalRuleDecoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
            ),
          ),
          ?footer,
        ]);
      },
    );
  }
}

/// 判斷邏輯說明頁(更多選單 ④)。最上方與最下方的免責文字寫在 judgement_guide.md 裡。
class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) => const MarkdownAsset(asset: 'judgement_guide');
}

/// 使用者條款、隱私權政策。
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) => MarkdownAsset(asset: asset, footer: const DisclaimerText(Disclaimers.general));
}
