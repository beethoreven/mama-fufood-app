import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:package_info_plus/package_info_plus.dart';

import '../core/log.dart';
import '../data/database.dart';
import '../data/store.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'daily_check.dart';
import 'diagnostics.dart';
import 'drive_store.dart';
import 'export_service.dart';
import 'feedback_service.dart';
import 'import_service.dart';
import 'photo_service.dart';
import 'sync_engine.dart';

/// App 用到的服務,在 main() 建立一次。
class Services {
  Services._({
    required this.store,
    required this.auth,
    required this.api,
    required this.diagnostics,
    required this.package,
  });

  final Store store;
  final AuthService auth;
  final ApiClient api;
  final Diagnostics diagnostics;
  final PackageInfo package;
  late final DailyCheckService check;
  late final PhotoService photos;
  late final SyncEngine sync;
  late final ExportService exporter;
  late final ImportService importer;
  late final FeedbackService feedback;

  String get appVersion => package.version;

  String get buildNumber => package.buildNumber;

  static Future<Services> create() async {
    // AES-GCM 用 Android 內建的實作(cryptography_flutter 外掛會自動啟用,比純 Dart 快很多)。
    final store = Store(AppDb.open());
    final diagnostics = Diagnostics(store);
    await diagnostics.init();
    final auth = AuthService(StoreAuthStorage(store));
    final services = Services._(
      store: store,
      auth: auth,
      api: ApiClient(auth),
      diagnostics: diagnostics,
      package: await PackageInfo.fromPlatform(),
    );
    services._wire();
    AppLog.info('app.start', {'version': services.appVersion, 'build': services.buildNumber});
    return services;
  }

  /// 畫面測試用(test/ui/):資料庫由測試給(放在記憶體),沒有登入、不連網。
  @visibleForTesting
  factory Services.forTest({required Store store, required Diagnostics diagnostics, required PackageInfo package}) {
    final auth = AuthService(StoreAuthStorage(store));
    return Services._(store: store, auth: auth, api: ApiClient(auth), diagnostics: diagnostics, package: package).._wire();
  }

  void _wire() {
    auth.exchange = api.createSession;
    check = DailyCheckService(store: store, auth: auth, api: api, appVersion: () => appVersion);
    photos = PhotoService(
      store,
      cloud: () => auth.signedIn ? GoogleDriveStore(auth, interactive: false) : null,
      cloudEnabled: () async => await store.getSetting(Keys.syncPhotos) == '1',
    );
    sync = SyncEngine(
      store: store,
      cloud: () => auth.signedIn ? GoogleDriveStore(auth, interactive: false) : null,
      enabled: () async => await store.getSetting(Keys.syncRecords) == '1',
    );
    exporter = ExportService(store: store, photos: photos, appVersion: () => appVersion);
    importer = ImportService(store: store, photos: photos, api: api, appVersion: () => appVersion);
    feedback = FeedbackService(
      store: store,
      api: api,
      auth: auth,
      diagnostics: diagnostics,
      appVersion: () => appVersion,
      buildNumber: () => buildNumber,
    );
  }

  /// 使用者按了按鈕的操作用這個:沒有雲端硬碟權限時會跳出 Google 的授權畫面。
  CloudStore interactiveCloud() => GoogleDriveStore(auth, interactive: true);

  /// 開 App、回到前景時:每日檢查、同步、照片上傳、重送意見回饋。都不擋畫面。
  Future<void> onForeground() async {
    try {
      await check.maybeRun();
    } catch (_) {}
    sync.onForeground();
    photos.processCloud();
    try {
      await feedback.retryQueued();
    } catch (_) {}
  }
}

/// 登入狀態存在本機資料庫的設定裡(和其他設定一樣,會跟著 Android 的自動備份)。
class StoreAuthStorage implements AuthStorage {
  StoreAuthStorage(this.store);

  final Store store;

  @override
  Future<String?> read(String key) => store.getSetting(key);

  @override
  Future<void> write(String key, String? value) => store.setSetting(key, value);
}
