import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/env.dart';
import '../core/log.dart';
import '../core/time.dart';

/// 雲端硬碟的權限(SPEC 第 6 節:用到才要求)。
abstract final class DriveScopes {
  /// 只能存取本 App 自己的雲端資料區:紀錄同步、匯出檔的金鑰。
  static const appData = 'https://www.googleapis.com/auth/drive.appdata';

  /// 只能存取本 App 建立或使用者選擇的檔案:匯出檔、雲端的照片。
  static const file = 'https://www.googleapis.com/auth/drive.file';

  static const all = [appData, file];
}

class SignedInUser {
  const SignedInUser({required this.sub, required this.email, this.name, this.photoUrl});

  final String sub;
  final String email;
  final String? name;
  final String? photoUrl;
}

class NotSignedIn implements Exception {
  const NotSignedIn();

  @override
  String toString() => '請先用 Google 帳號登入';
}

class DriveNotAuthorized implements Exception {
  const DriveNotAuthorized();

  @override
  String toString() => '需要雲端硬碟的權限';
}

/// Google 登入(SPEC 第 6 節)。
///
/// - 登入時只要求基本資料(Email、名稱、頭像);雲端硬碟權限在開啟雲端功能或
///   第一次匯出、匯入時才要求。
/// - Android 上用系統的帳號選擇畫面(Credential Manager),不開瀏覽器(google_sign_in 7)。
/// - ★ 後端請求每次都要帶一張**新的** ID token(約一小時過期),不能把舊的當長期憑證。
///   idToken() 會在快過期前換一張新的。
class AuthService extends ChangeNotifier {
  AuthService({GoogleSignIn? signIn}) : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;
  GoogleSignInAccount? _account;
  String? _idToken;
  DateTime? _idTokenExpiry;
  bool _initialized = false;

  SignedInUser? get user {
    final a = _account;
    if (a == null) return null;
    return SignedInUser(sub: a.id, email: a.email, name: a.displayName, photoUrl: a.photoUrl);
  }

  bool get signedIn => _account != null;

  Future<void> init() async {
    if (_initialized || !Env.googleConfigured) return;
    _initialized = true;
    try {
      await _signIn.initialize(serverClientId: Env.webClientId);
      _signIn.authenticationEvents.listen((event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn():
            _setAccount(event.user);
          case GoogleSignInAuthenticationEventSignOut():
            _setAccount(null);
        }
      }, onError: (Object e) => AppLog.warn('auth.event_error', {'type': e.runtimeType.toString()}));
      // 之前登入過的話,不跳畫面直接恢復登入狀態。
      final account = await _signIn.attemptLightweightAuthentication();
      if (account != null) _setAccount(account);
    } catch (e, st) {
      AppLog.error('auth.init_failed', e, st);
    }
  }

  void _setAccount(GoogleSignInAccount? account) {
    _account = account;
    // 送出的診斷資料裡,出現帳號的顯示名稱(通常是本名)就遮蔽(SPEC 第 10 節)。
    AppLog.accountName = account?.displayName;
    final token = account?.authentication.idToken;
    _rememberToken(token);
    notifyListeners();
  }

  void _rememberToken(String? token) {
    _idToken = token;
    _idTokenExpiry = token == null ? null : _expiryOf(token);
  }

  static DateTime? _expiryOf(String jwt) {
    try {
      final body = jwt.split('.')[1];
      final json = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(body)))) as Map;
      return DateTime.fromMillisecondsSinceEpoch((json['exp'] as int) * 1000, isUtc: true);
    } catch (_) {
      return null;
    }
  }

  /// 使用者按下登入。
  Future<SignedInUser> signIn() async {
    if (!Env.googleConfigured) throw StateError('這個版本還沒設定 Google 登入');
    await init();
    final account = await _signIn.authenticate();
    _setAccount(account);
    AppLog.info('auth.signed_in');
    return user!;
  }

  Future<void> signOut() async {
    try {
      await _signIn.signOut();
    } finally {
      _setAccount(null);
      AppLog.info('auth.signed_out');
    }
  }

  /// 給後端的 ID token:手上的這張還有 5 分鐘以上就用它,否則不跳畫面換一張新的。
  /// 換不到(需要使用者操作)就丟 NotSignedIn,呼叫端請使用者重新登入。
  Future<String> idToken() async {
    final expiry = _idTokenExpiry;
    final now = TimeRules.now().toUtc();
    if (_idToken != null && expiry != null && expiry.isAfter(now.add(const Duration(minutes: 5)))) {
      return _idToken!;
    }
    if (!Env.googleConfigured) throw const NotSignedIn();
    await init();
    final account = await _signIn.attemptLightweightAuthentication();
    if (account == null) throw const NotSignedIn();
    _setAccount(account);
    final token = _idToken;
    final fresh = _idTokenExpiry;
    if (token == null || (fresh != null && !fresh.isAfter(now.add(const Duration(minutes: 1))))) {
      throw const NotSignedIn();
    }
    return token;
  }

  /// 後端回 401 時呼叫:丟掉手上的 token,下次 idToken() 會換新的。
  void invalidateIdToken() => _rememberToken(null);

  /// 雲端硬碟的存取權杖。interactive = true 時,沒有權限會跳出 Google 的授權畫面
  /// (只能在使用者按下按鈕時用);false 時沒有權限就丟 DriveNotAuthorized。
  Future<String> driveAccessToken({required bool interactive}) async {
    final account = _account;
    if (account == null) throw const NotSignedIn();
    final client = account.authorizationClient;
    var authz = await client.authorizationForScopes(DriveScopes.all);
    if (authz == null) {
      if (!interactive) throw const DriveNotAuthorized();
      authz = await client.authorizeScopes(DriveScopes.all);
      AppLog.info('auth.drive_authorized');
    }
    return authz.accessToken;
  }

  /// 雲端硬碟回 401 時呼叫:這張存取權杖已經失效,讓系統下次給新的。
  Future<void> dropDriveToken(String accessToken) async {
    final account = _account;
    if (account == null) return;
    await account.authorizationClient.clearAuthorizationToken(accessToken: accessToken);
  }
}
