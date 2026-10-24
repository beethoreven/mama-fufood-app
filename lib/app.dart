import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'ui/gate.dart';
import 'ui/theme.dart';
import 'ui/widgets/wheel_picker.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class MamaApp extends ConsumerWidget {
  const MamaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = settingsOf(ref);
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: '媽媽記副食品',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // 預設深色(深夜哄睡後使用);設定讀到之前也先用深色,避免開 App 白屏閃一下。
      themeMode: ref.watch(settingsProvider).hasValue ? settings.themeMode : ThemeMode.dark,
      locale: const Locale('zh', 'TW'),
      supportedLocales: const [Locale('zh', 'TW')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // 選單自動選定的時間跟著 App 設定(所有選單都在這底下,包括 showDialog 開的)。
      builder: (context, child) =>
          PickerTiming(autoApply: settings.pickerAutoApply, idleApply: settings.pickerIdleApply, child: child!),
      home: AppGate(navigatorKey: navigatorKey),
    );
  }
}
