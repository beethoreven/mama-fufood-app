import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mama_fufood/data/database.dart';
import 'package:mama_fufood/data/store.dart';
import 'package:mama_fufood/domain/record.dart';
import 'package:mama_fufood/services/api_client.dart';
import 'package:mama_fufood/services/auth_service.dart';
import 'package:mama_fufood/services/export_format.dart';
import 'package:mama_fufood/services/import_service.dart';
import 'package:mama_fufood/services/photo_service.dart';
import 'package:mama_fufood/services/services.dart';

Map<String, Object?> _load(String name) =>
    (jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map).cast<String, Object?>();

/// 不同格式的整合:第 0 版(上架前)的匯出檔,匯入時只把 data.json 送後端轉成第 1 版再匯入。
void main() {
  late Store store;
  late List<http.Request> requests;
  late ImportService importer;

  setUp(() async {
    store = Store(AppDb(NativeDatabase.memory()));
    await store.setSetting('auth_user', jsonEncode({'sub': 'u1', 'email': 'mom@example.com'}));
    await store.setSetting('auth_app_token', 'mff1.x.y');
    await store.setSetting('auth_app_token_exp', '${DateTime.now().add(const Duration(days: 100)).millisecondsSinceEpoch ~/ 1000}');
    final auth = AuthService(StoreAuthStorage(store));
    await auth.init();
    requests = [];
    // 假後端:照後端的「第 0 版轉第 1 版」規則轉(每筆紀錄補 digestive: null)。
    final api = ApiClient(auth, baseUrl: 'https://backend.test', client: MockClient((req) async {
      requests.add(req);
      final old = (jsonDecode(utf8.decode(gzip.decode(req.bodyBytes))) as Map).cast<String, Object?>();
      final converted = jsonDecode(jsonEncode(old)) as Map<String, Object?>;
      converted['format_version'] = 1;
      for (final b in converted['babies']! as List) {
        for (final r in (b as Map)['records'] as List) {
          (r as Map)['digestive'] = null;
        }
      }
      return http.Response(jsonEncode({'format_version': 1, 'data': converted, 'missing': []}), 200,
          headers: {'content-type': 'application/json'});
    }));
    importer = ImportService(
        store: store,
        photos: PhotoService(store, cloud: () => null, cloudEnabled: () async => false),
        api: api,
        appVersion: () => '1.0.0');
  });

  tearDown(() => store.db.close());

  test('第 0 版的檔案：送後端轉換後通過第 1 版的檢查，腹瀉或嘔吐是空的', () async {
    final steps = <String>[];
    final parsed = await importer.upgradeAndParse(_load('export_v0_sample.json'), progress: steps.add);
    expect(requests.single.url.path, '/api/v1/convert');
    expect(steps, ['轉換舊格式']);
    final records = parsed.babies.expand((b) => b.records).toList();
    expect(records, isNotEmpty);
    expect(records.every((r) => r.digestive == null), isTrue);
  });

  test('第 1 版的檔案：不送後端，直接檢查', () async {
    final parsed = await importer.upgradeAndParse(_load('export_v1_sample.json'));
    expect(requests, isEmpty);
    expect(parsed.babies.expand((b) => b.records).map((r) => r.digestive),
        containsAll([Digestive.normal, Digestive.diarrhea]));
  });

  test('比這支 App 新的格式：請使用者更新 App', () async {
    final newer = _load('export_v1_sample.json')..['format_version'] = ExportFormat.version + 1;
    expect(() => importer.upgradeAndParse(newer), throwsA(isA<ImportProblem>()));
    expect(requests, isEmpty);
  });
}
