import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mama_fufood/services/auth_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MemoryStorage implements AuthStorage {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async =>
      value == null ? values.remove(key) : values[key] = value;
}

class _FakePlatform extends GoogleSignInPlatform with MockPlatformInterfaceMixin {
  final requests = <AuthorizationRequestDetails>[];
  bool granted = true;
  int lightweightCalls = 0;

  @override
  Future<void> init(InitParameters params) async {}

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(AttemptLightweightAuthenticationParameters params) {
    lightweightCalls++;
    return Future.value(null);
  }

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) => throw UnimplementedError();

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
      ClientAuthorizationTokensForScopesParameters params) async {
    requests.add(params.request);
    return granted || params.request.promptIfUnauthorized ? const ClientAuthorizationTokenData(accessToken: 'drive-at') : null;
  }

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
          ServerAuthorizationTokensForScopesParameters params) async =>
      null;

  @override
  Future<void> clearAuthorizationToken(ClearAuthorizationTokenParams params) async {}

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

/// 登入一次就記住:開 App 不請系統「自動登入」(那會在系統不肯時跳出選帳號畫面)。
void main() {
  late _MemoryStorage storage;
  late _FakePlatform platform;

  setUp(() {
    storage = _MemoryStorage();
    platform = _FakePlatform();
    GoogleSignInPlatform.instance = platform;
  });

  Future<AuthService> restored({String? token, DateTime? expiry}) async {
    storage.values['auth_user'] = jsonEncode({'sub': 'u1', 'email': 'mom@example.com', 'name': '媽媽', 'photo': null});
    if (token != null) {
      storage.values['auth_app_token'] = token;
      storage.values['auth_app_token_exp'] = '${expiry!.millisecondsSinceEpoch ~/ 1000}';
    }
    final auth = AuthService(storage);
    await auth.init();
    return auth;
  }

  test('重開 App:記住的帳號直接是登入狀態，不會請系統自動登入', () async {
    final auth = await restored(token: 'mff1.a.b', expiry: DateTime.now().toUtc().add(const Duration(days: 100)));
    expect(auth.signedIn, isTrue);
    expect(auth.user!.email, 'mom@example.com');
    expect(platform.lightweightCalls, 0);
    expect(await auth.backendToken(), 'mff1.a.b');
  });

  test('沒登入過:不是登入狀態，後端請求要先登入', () async {
    final auth = AuthService(storage);
    await auth.init();
    expect(auth.signedIn, isFalse);
    expect(auth.backendToken, throwsA(isA<NotSignedIn>()));
  });

  test('通行證快過期或被後端拒絕:用這次登入的 ID Token 換一張；換不到就請使用者重新登入', () async {
    final auth = await restored(token: 'mff1.old', expiry: DateTime.now().toUtc().add(const Duration(hours: 2)));
    var exchanged = 0;
    auth.exchange = (idToken) async {
      exchanged++;
      return (token: 'mff1.new', expiresAt: DateTime.now().toUtc().add(const Duration(days: 180)).millisecondsSinceEpoch ~/ 1000);
    };
    // 這次開 App 沒按登入,手上沒有 ID Token:換不到。
    expect(auth.backendToken, throwsA(isA<NotSignedIn>()));
    auth.debugSetIdToken('google-id', DateTime.now().toUtc().add(const Duration(minutes: 30)));
    expect(await auth.backendToken(), 'mff1.new');
    expect(exchanged, 1);
    expect(storage.values['auth_app_token'], 'mff1.new', reason: '換到的通行證要存起來,下次開 App 還在');

    await auth.invalidateBackendToken();
    expect(storage.values.containsKey('auth_app_token'), isFalse);
  });

  test('每日檢查附的新通行證會換上', () async {
    final auth = await restored(token: 'mff1.old', expiry: DateTime.now().toUtc().add(const Duration(days: 100)));
    await auth.renewBackendToken('mff1.renewed', DateTime.now().toUtc().add(const Duration(days: 180)).millisecondsSinceEpoch ~/ 1000);
    expect(await auth.backendToken(), 'mff1.renewed');
  });

  test('登出:帳號與通行證都清掉', () async {
    final auth = await restored(token: 'mff1.a.b', expiry: DateTime.now().toUtc().add(const Duration(days: 100)));
    await auth.signOut();
    expect(auth.signedIn, isFalse);
    expect(storage.values, isEmpty);
  });

  test('雲端硬碟授權:指定記住的帳號，不跳畫面；沒有授權時只有使用者按按鈕才跳', () async {
    final auth = await restored();
    expect(await auth.driveAccessToken(interactive: false), 'drive-at');
    expect(platform.requests.single.userId, 'u1');
    expect(platform.requests.single.email, 'mom@example.com');
    expect(platform.requests.single.promptIfUnauthorized, isFalse);

    platform.granted = false;
    expect(() => auth.driveAccessToken(interactive: false), throwsA(isA<DriveNotAuthorized>()));
    expect(await auth.driveAccessToken(interactive: true), 'drive-at');
    expect(platform.requests.last.promptIfUnauthorized, isTrue);
    expect(platform.lightweightCalls, 0);
  });
}
