import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/services/export_crypto.dart';
import 'package:mama_fufood/services/export_format.dart';
import 'package:mama_fufood/services/export_keys.dart';

import 'fake_cloud.dart';

Map<String, Object?> sample() => (jsonDecode(File('test/fixtures/export_v1_sample.json').readAsStringSync()) as Map)
    .cast<String, Object?>();

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('mff_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  MffHeader header(String keyId) => MffHeader(
        formatVersion: 1,
        appVersion: '1.0.0',
        exportedAt: '2026-10-23T08:30:00.000Z',
        keyId: keyId,
        noncePrefix: base64.encode(MffCrypto.randomBytes(8)),
      );

  group('匯出格式：和後端是同一份規則（export_formats/samples/v1.json）', () {
    test('後端的樣本檔 App 也認得', () {
      final parsed = ExportFormat.parse(sample());
      expect(parsed.babies.map((b) => b.name), ['小寶', '二寶']);
      expect(parsed.babies.first.records.first.eatenCenti, 2550);
      expect(parsed.babies.first.records[1].allergy, isNull);
      expect(parsed.photoIds, {'9d8e7f6a-5b4c-4d3e-8f2a-1b0c9d8e7f6a'});
    });

    test('編碼再解析回來一模一樣', () {
      final parsed = ExportFormat.parse(sample());
      final again = ExportFormat.encodeRecord(parsed.babies.first.records.first, photosAsPaths: true);
      expect(again, (sample()['babies'] as List).first['records'][0]);
    });

    for (final (label, mutate) in <(String, void Function(Map<String, Object?>))>[
      ('數量超過 999.99', (d) => ((d['babies'] as List).first['records'] as List).first['eaten_amount'] = 1000),
      ('超過 2 位小數', (d) => ((d['babies'] as List).first['records'] as List).first['eaten_amount'] = 1.005),
      ('照片路徑跳出資料夾', (d) => ((d['babies'] as List).first['records'] as List).first['photos'] = ['../x.jpg']),
      ('寶寶名稱重複', (d) => (d['babies'] as List)[1]['name'] = '小寶'),
      ('不認得的欄位', (d) => ((d['babies'] as List).first['records'] as List).first['extra'] = 1),
      ('週起始日只有星期一、星期日', (d) => (d['settings'] as Map)['week_start'] = 'saturday'),
      ('格式版本不對', (d) => d['format_version'] = 2),
    ]) {
      test('擋下：$label', () {
        final d = sample();
        mutate(d);
        expect(() => ExportFormat.parse(d), throwsFormatException);
      });
    }
  });

  group('加密（AES-256-GCM，每段 1 MiB）', () {
    final key = MffCrypto.randomBytes(32);

    Future<File> roundTrip(List<int> content) async {
      final plain = File('${tmp.path}/plain.bin')..writeAsBytesSync(content);
      final mff = File('${tmp.path}/out.mff');
      await MffCrypto.encryptFile(plain: plain, out: mff, header: header('k1'), key: key);
      return mff;
    }

    test('多段內容加密再解密，一個位元組都不差', () async {
      final content = List<int>.generate(MffCrypto.segment * 2 + 12345, (i) => (i * 31) % 251);
      final mff = await roundTrip(content);
      final (h, _) = (await MffCrypto.readHeader(mff))!;
      expect(h.keyId, 'k1');
      final back = File('${tmp.path}/back.bin');
      await MffCrypto.decryptFile(mff: mff, out: back, key: key);
      expect(back.readAsBytesSync(), content);
    });

    test('剛好整段的長度也可以', () async {
      final content = List<int>.filled(MffCrypto.segment, 7);
      final back = File('${tmp.path}/back.bin');
      await MffCrypto.decryptFile(mff: await roundTrip(content), out: back, key: key);
      expect(back.lengthSync(), MffCrypto.segment);
    });

    test('改了一個位元、截掉最後一段、改了檔頭、用錯金鑰：都解不開', () async {
      final content = List<int>.generate(MffCrypto.segment + 100, (i) => i % 256);
      final mff = await roundTrip(content);
      final bytes = mff.readAsBytesSync();
      final back = File('${tmp.path}/back.bin');

      final flipped = Uint8List.fromList(bytes)..[bytes.length - 50] ^= 1;
      final f1 = File('${tmp.path}/f1.mff')..writeAsBytesSync(flipped);
      await expectLater(MffCrypto.decryptFile(mff: f1, out: back, key: key), throwsA(isA<MffCorrupted>()));

      // 截掉最後一段:剩下的最後一段當初是用「不是最後一段」的標記加密的,解得出來就是漏洞。
      final truncated = bytes.sublist(0, bytes.length - 100 - 16);
      final f2 = File('${tmp.path}/f2.mff')..writeAsBytesSync(truncated);
      await expectLater(MffCrypto.decryptFile(mff: f2, out: back, key: key), throwsA(isA<MffCorrupted>()));

      // 把檔頭的 App 版本改小(想繞過版本檢查)。
      final text = latin1.decode(bytes);
      final tampered = latin1.encode(text.replaceFirst('"app_version":"1.0.0"', '"app_version":"0.0.1"'));
      final f3 = File('${tmp.path}/f3.mff')..writeAsBytesSync(tampered);
      await expectLater(MffCrypto.decryptFile(mff: f3, out: back, key: key), throwsA(isA<MffCorrupted>()));

      await expectLater(MffCrypto.decryptFile(mff: mff, out: back, key: MffCrypto.randomBytes(32)), throwsA(isA<MffCorrupted>()));
    });

    test('不是匯出檔的檔案', () async {
      final f = File('${tmp.path}/x.zip')..writeAsBytesSync(utf8.encode('PK not ours'));
      expect(await MffCrypto.readHeader(f), isNull);
    });
  });

  group('金鑰：一個帳號一把，另做防呆', () {
    test('沒有就建立；之後一律用同一把', () async {
      final cloud = FakeCloud();
      final k1 = await ExportKeys(cloud).getOrCreate();
      final k2 = await ExportKeys(cloud).getOrCreate();
      expect(k2.id, k1.id);
      expect((await ExportKeys(cloud).find(k1.id))!.bytes, k1.bytes);
      expect(await ExportKeys(cloud).find('nope'), isNull);
    });

    test('讀取失敗（斷網）不會另外建立一把', () async {
      final cloud = FakeCloud()..offline = true;
      await expectLater(ExportKeys(cloud).getOrCreate(), throwsA(anything));
      cloud.offline = false;
      expect(cloud.files, isEmpty);
    });

    test('兩支手機同時建立了兩把：大家都改用最早的那把，兩把都還找得到', () async {
      final cloud = FakeCloud();
      final keys = ExportKeys(cloud);
      final early = utf8.encode(jsonEncode({'key_id': 'early', 'key': base64.encode(List.filled(32, 1)), 'created_at': 1000}));
      final late = utf8.encode(jsonEncode({'key_id': 'late', 'key': base64.encode(List.filled(32, 2)), 'created_at': 2000}));
      await cloud.createAppData('mff_key_late.json', Uint8List.fromList(late));
      await cloud.createAppData('mff_key_early.json', Uint8List.fromList(early));
      expect((await keys.getOrCreate()).id, 'early');
      expect((await keys.find('late'))!.bytes, List.filled(32, 2));
    });
  });
}
