import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/domain/record.dart';
import 'package:mama_fufood/ui/theme.dart';
import 'package:mama_fufood/ui/widgets/common.dart';

/// 「腹瀉或嘔吐」的選法:正常和另外兩個互斥(點了沒反應),腹瀉、嘔吐可以同時選,再點一次取消。
void main() {
  testWidgets('選法規則', (tester) async {
    Digestive? value;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => DigestiveChips(value: value, onChanged: (v) => setState(() => value = v)),
        ),
      ),
    ));
    Future<void> tap(String label) async {
      await tester.tap(find.text(label));
      await tester.pump();
    }

    await tap('正常');
    expect(value, Digestive.normal);
    await tap('腹瀉'); // 選了正常:點腹瀉沒反應
    await tap('嘔吐');
    expect(value, Digestive.normal);
    await tap('正常'); // 再點一次取消
    expect(value, isNull);

    await tap('腹瀉');
    expect(value, Digestive.diarrhea);
    await tap('嘔吐');
    expect(value, Digestive.both);
    await tap('正常'); // 選了腹瀉、嘔吐:點正常沒反應
    expect(value, Digestive.both);
    await tap('腹瀉');
    expect(value, Digestive.vomiting);
    await tap('嘔吐');
    expect(value, isNull);
  });
}
