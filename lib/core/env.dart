/// 建置時帶入的設定(不是秘密,但每個人的 Google Cloud 與 Render 設定不同)。
///
///     flutter build apk --release --dart-define-from-file=env/prod.json
///
/// env/prod.json 的格式見 env/prod.example.json;沒帶的話 App 照常可以在手機上記錄,
/// 只是登入、檢查更新、意見回饋等連網功能會顯示「還沒設定」。
abstract final class Env {
  /// 後端網址,例如 https://mama-fufood-backend.onrender.com(不要結尾斜線)。
  static const apiBase = String.fromEnvironment('MFF_API_BASE');

  /// Google Cloud 的「網頁應用程式」用戶端 ID(後端驗證 ID token 用的也是這一個)。
  static const webClientId = String.fromEnvironment('MFF_WEB_CLIENT_ID');

  static bool get backendConfigured => apiBase.isNotEmpty;

  static bool get googleConfigured => webClientId.isNotEmpty;
}
