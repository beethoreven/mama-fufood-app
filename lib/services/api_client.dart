import 'dart:convert';
import 'dart:io' show Platform, gzip;

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

/// 呼叫後端。每一支都帶 App 的通行證(見 AuthService.backendToken;登入時用 Google ID Token 換來的)。
class ApiClient {
  /// baseUrl 只給測試用;App 一律用建置時帶入的 Env.apiBase。
  ApiClient(this.auth, {http.Client? client, String? baseUrl})
      : _http = client ?? http.Client(),
        _base = baseUrl ?? Env.apiBase;

  final AuthService auth;
  final http.Client _http;
  final String _base;

  bool get configured => _base.isNotEmpty;
  static const _timeout = Duration(seconds: 30);

  Uri _url(String path) => Uri.parse('$_base$path');

  Future<Map<String, dynamic>> _post(String path, Object body, {bool gzipBody = false, bool retried = false}) async {
    if (!configured) throw const ApiError(0, 'not_configured', '這個版本還沒設定後端網址');
    final token = await auth.backendToken();
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
      throw const ApiError(0, 'network', '無法連線到伺服器，請確認網路後再試');
    }
    if (resp.statusCode == 401 && !retried) {
      // 通行證無效或過期:丟掉,再試一次(這次登入的 ID Token 還在的話會換一張新的;
      // 換不到就丟 NotSignedIn,請使用者重新登入)。
      await auth.invalidateBackendToken();
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
          (json['error'] as String?) ?? '伺服器回應錯誤（${resp.statusCode}）', json);
    }
    return json;
  }

  /// 登入時呼叫一次:用 Google ID Token 換 App 的通行證。
  Future<({String token, int expiresAt})> createSession(String idToken) async {
    if (!configured) throw const ApiError(0, 'not_configured', '這個版本還沒設定後端網址');
    http.Response resp;
    try {
      resp = await _http
          .post(_url('/api/v1/session'), headers: {'Authorization': 'Bearer $idToken'})
          .timeout(_timeout);
    } catch (e) {
      AppLog.warn('api.network_error', {'path': '/api/v1/session', 'type': e.runtimeType.toString()});
      throw const ApiError(0, 'network', '無法連線到伺服器，請確認網路後再試');
    }
    Map<String, dynamic> json;
    try {
      json = (jsonDecode(utf8.decode(resp.bodyBytes)) as Map).cast<String, dynamic>();
    } catch (_) {
      json = {};
    }
    AppLog.info('api.response', {'path': '/api/v1/session', 'status': resp.statusCode, 'code': json['code'] as String?});
    final token = json['token'];
    final exp = json['expires_at'];
    if (resp.statusCode != 200 || token is! String || exp is! int) {
      throw ApiError(resp.statusCode, (json['code'] as String?) ?? 'http_${resp.statusCode}',
          (json['error'] as String?) ?? '伺服器回應錯誤（${resp.statusCode}）', json);
    }
    return (token: token, expiresAt: exp);
  }

  /// 每日檢查(SPEC 第 3 節第 2 項)。
  Future<Map<String, dynamic>> check({required String appVersion, required Map<String, Map<String, Object?>> datasets}) =>
      _post('/api/v1/check',
          {'app_version': appVersion, 'platform': Platform.isIOS ? 'ios' : 'android', 'datasets': datasets});

  /// 意見回饋。
  Future<Map<String, dynamic>> feedback(Map<String, Object?> body) => _post('/api/v1/feedback', body);

  /// 舊格式轉換:只送 data.json(不含照片),壓縮後送出。
  Future<Map<String, dynamic>> convert(Map<String, Object?> dataJson) =>
      _post('/api/v1/convert', dataJson, gzipBody: true);
}
