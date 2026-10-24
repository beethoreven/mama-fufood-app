import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/core/log.dart';

/// 送出的診斷資料(錯誤訊息、堆疊、logcat、追蹤摘要)送出前要遮蔽的個人資料與憑證(SPEC 第 10 節)。
void main() {
  setUp(() {
    AppLog.babyNames = const ['小寶'];
    AppLog.accountName = '王小明';
  });
  tearDown(() {
    AppLog.babyNames = const [];
    AppLog.accountName = null;
  });

  for (final (label, input, hidden) in <(String, String, String)>[
    ('Email', 'sent by mama@example.com', 'mama@example.com'),
    ('ID token', 'token eyJhbGciOi.eyJzdWIiOi.c2lnbmF0dXJl', 'eyJhbGciOi.eyJzdWIiOi.c2lnbmF0dXJl'),
    ('存取權杖', 'access ya29.a0AfB_byC-1234', 'ya29.a0AfB_byC-1234'),
    ('Bearer', 'Authorization: Bearer abc.def', 'abc.def'),
    ('網址的查詢參數', 'GET https://x.example/api?token=abc', 'token=abc'),
    ('檔名', 'open 小寶_20261023.mff failed', '小寶_20261023'),
    ('引號內的文字', 'parse "嘴巴有點紅" failed', '嘴巴有點紅'),
    ('IP', 'connect 192.168.1.20 refused', '192.168.1.20'),
    ('雲端硬碟的檔案編號', 'file 1AbCdEfGhIjKlMnOpQrStUvWxYz0123 missing', '1AbCdEfGhIjKlMnOpQrStUvWxYz0123'),
    ('網址裡的檔案編號', 'GET https://www.googleapis.com/drive/v3/files/1AbCdEfGhIjKlMnOpQrStUvWxYz0123/content',
        '1AbCdEfGhIjKlMnOpQrStUvWxYz0123'),
    ('寶寶名稱', '小寶 的紀錄', '小寶'),
    ('帳號的顯示名稱', 'signed in as 王小明', '王小明'),
    ('手機（連字號）', 'call 0900-000-000', '0900-000-000'),
    ('手機（連在一起）', 'call 0900000000 now', '0900000000'),
    ('手機（+886）', 'call +886 900 000 000', '900 000 000'),
    ('市話（括號）', 'call (02) 0000-0000', '0000-0000'),
    ('市話（連字號）', 'call 04-0000-0000', '0000-0000'),
    ('Android ID', 'android_id=9774d56d682e549c', '9774d56d682e549c'),
  ]) {
    test('遮蔽：$label', () {
      final out = AppLog.redact(input);
      expect(out, isNot(contains(hidden)), reason: out);
    });
  }

  for (final (label, input) in <(String, String)>[
    ('紀錄的 UUID（除錯需要）', 'record 9d8e7f6a-5b4c-4d3e-8f2a-1b0c9d8e7f6a saved'),
    ('毫秒時間戳', 'at 1792731600000'),
    ('版本號', 'app 1.0.0+1000'),
    ('程式碼位置', 'package:mama_fufood/ui/shell.dart:123:45'),
    ('狀態碼與時間', 'HTTP 503 after 0:00:05.000000'),
  ]) {
    test('保留：$label', () => expect(AppLog.redact(input), input));
  }

  test('一個字的顯示名稱不比對（太容易誤傷其他文字）', () {
    AppLog.accountName = '明';
    expect(AppLog.redact('明天再試'), '明天再試');
  });

  test('登出後不再遮蔽之前的帳號名稱', () {
    AppLog.accountName = null;
    expect(AppLog.redact('王小明'), '王小明');
  });

  test('超過 300 字截斷', () => expect(AppLog.redact('字' * 400).length, 301));
}
