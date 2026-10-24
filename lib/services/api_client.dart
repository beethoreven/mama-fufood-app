import 'dart:convert';
import 'dart:io' show gzip;

import 'package:http/http.dart' as http;

import '../core/env.dart';
import '../core/log.dart';
import 'auth_service.dart';

class ApiError implements Exception {
  const ApiError(this.status, this.code, this.message, [this.body]);

  final int status;
  final String code;
  final String message;
  final Map<String, dynamic>? body;

  bool get isDailyLimit => status == 429;

  bool get isNotReady => status == 503;

  bool get isNetwork => status == 0;

  @override
  String toString() => message;
}

/// 呼叫後端。每一支都帶 Google ID token(每次一張新的,見 AuthService.idToken)。
class ApiClient {
  ApiClient(this.auth, {http.Client? client}) : _http = client ?? http.Client();

  final AuthService auth;
  final http.Client _http;
  static const _timeout = Duration(seconds: 30);

  Uri _url(String path) => Uri.parse('${Env.apiBase}$path');

  Future<Map<String, dynamic>> _post(String path, Object body, {bool gzipBody = false, bool retried = false}) async {
    if (!Env.backendConfigured) throw const ApiError(0, 'not_configured', '這個版本還沒設定後端網址');
    final token = await auth.idToken();
    final raw = utf8.encode(jsonEncode(body));
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept-Encoding': 'gzip',
      if (gzipBody) 'Content-Encoding': 'gzip',
    };
    http.Response resp;
    try {
      resp = await _http
          .post(_url(path), headers: headers, body: gzipBody ? gzip.encode(raw) : raw)
          .timeout(path == '/api/v1/convert' ? const Duration(minutes: 3) : _timeout);
    } catch (e) {
      AppLog.warn('api.network_error', {'path': path, 'type': e.runtimeType.toString()});
      throw const ApiError(0, 'network', '無法連線到伺服器,請確認網路後再試');
    }
    if (resp.statusCode == 401 && !retried) {
      // ID token 可能剛好過期:丟掉、換一張新的再試一次。
      auth.invalidateIdToken();
      return _post(path, body, gzipBody: gzipBody, retried: true);
    }
    Map<String, dynamic> json;
    try {
      json = (jsonDecode(utf8.decode(resp.bodyBytes)) as Map).cast<String, dynamic>();
    } catch (_) {
      json = {};
    }
    AppLog.info('api.response', {'path': path, 'status': resp.statusCode, 'code': json['code'] as String?});
    if (resp.statusCode >= 400) {
      throw ApiError(resp.statusCode, (json['code'] as String?) ?? 'http_${resp.statusCode}',
          (json['error'] as String?) ?? '伺服器回應錯誤(${resp.statusCode})', json);
    }
    return json;
  }

  /// 每日檢查(SPEC 第 3 節第 2 項)。
  Future<Map<String, dynamic>> check({required String appVersion, required Map<String, Map<String, Object?>> datasets}) =>
      _post('/api/v1/check', {'app_version': appVersion, 'platform': 'android', 'datasets': datasets});

  /// 意見回饋。
  Future<Map<String, dynamic>> feedback(Map<String, Object?> body) => _post('/api/v1/feedback', body);

  /// 舊格式轉換:只送 data.json(不含照片),壓縮後送出。
  Future<Map<String, dynamic>> convert(Map<String, Object?> dataJson) =>
      _post('/api/v1/convert', dataJson, gzipBody: true);
}
