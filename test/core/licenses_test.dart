import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/core/licenses.dart';

/// 打包的字型(Noto Sans TC)要在「開放原始碼授權」頁列出 SIL OFL 1.1 全文(授權條款的規定)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Noto Sans TC 的授權全文有登記', () async {
    LicenseRegistry.reset();
    registerBundledLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final font = entries.where((e) => e.packages.contains('Noto Sans TC')).toList();
    expect(font, hasLength(1));
    final text = font.single.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
    expect(text, contains('Copyright 2014-2021 Adobe'));
  });
}
