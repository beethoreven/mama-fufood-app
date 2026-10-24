import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'ui/gate.dart';
import 'ui/theme.dart';

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
      home: AppGate(navigatorKey: navigatorKey),
    );
  }
}
