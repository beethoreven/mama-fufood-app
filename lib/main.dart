import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/licenses.dart';
import 'core/log.dart';
import 'services/services.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledLicenses();
  // 當機捕捉(SPEC 第 10 節):Dart 層的錯誤寫進本機記錄檔;原生層由 MamaApp.kt 處理。
  FlutterError.onError = (details) {
    AppLog.error('flutter.error', details.exception, details.stack);
    if (kDebugMode) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.error('dart.uncaught', error, stack);
    return true;
  };
  // 只支援直向(SPEC 第 1 節);平板、摺疊機、橫向之後再擴充。
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final services = await Services.create();
  runApp(ProviderScope(
    overrides: [servicesProvider.overrideWithValue(services)],
    child: const MamaApp(),
  ));
}
