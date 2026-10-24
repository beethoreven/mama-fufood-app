import 'package:flutter/material.dart';

/// 設計規範:風格 C「可愛粉藍」(design/DESIGN_SYSTEM.md)。
/// 各畫面一律從這裡取值。所有文字與背景的對比度都在 4.5 以上(規範裡實測過)。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.text2,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.entryBg,
    required this.todayBg,
    required this.todayText,
    required this.deco,
    required this.ok,
    required this.warn,
    required this.danger,
    required this.like,
    required this.accept,
    required this.reject,
  });

  final Color bg, surface, surface2, border, text, text2, muted, accent, onAccent, accentSoft, entryBg;
  final Color todayBg, todayText, deco, ok, warn, danger, like, accept, reject;

  static const dark = AppColors(
    bg: Color(0xFF12161D),
    surface: Color(0xFF1A2029),
    surface2: Color(0xFF222A35),
    border: Color(0xFF2E3846),
    text: Color(0xFFECEFF4),
    text2: Color(0xFFAEB7C4),
    muted: Color(0xFF8E98A6),
    accent: Color(0xFF8EC9F5),
    onAccent: Color(0xFF0A2740),
    accentSoft: Color(0xFF213A52),
    entryBg: Color(0xFF1F3346),
    todayBg: Color(0xFFF5B99A),
    todayText: Color(0xFF3A1A0A),
    deco: Color(0xFFF5B99A),
    ok: Color(0xFF8ED6B5),
    warn: Color(0xFFF6CF7A),
    danger: Color(0xFFF59A92),
    like: Color(0xFFF7A8C8),
    accept: Color(0xFF8EC9F5),
    reject: Color(0xFFB6B2D2),
  );

  static const light = AppColors(
    bg: Color(0xFFF6F8FC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEDF3FA),
    border: Color(0xFFD9E2EC),
    text: Color(0xFF1A2230),
    text2: Color(0xFF4D5A6B),
    muted: Color(0xFF5E6A7A),
    accent: Color(0xFF2A74B0),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFE1EEFA),
    entryBg: Color(0xFFE6F1FB),
    todayBg: Color(0xFFFBE3D6),
    todayText: Color(0xFF8A3B1C),
    deco: Color(0xFFB85A35),
    ok: Color(0xFF23805A),
    warn: Color(0xFF956500),
    danger: Color(0xFFBC4339),
    like: Color(0xFFB04377),
    accept: Color(0xFF2A74B0),
    reject: Color(0xFF635F88),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < 0.5 ? this : (other as AppColors? ?? this);
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// Noto Sans TC 是可變字型:字重同時設 fontWeight 與 wght 軸,兩種渲染方式都對。
TextStyle weight(TextStyle style, int w) =>
    style.copyWith(fontWeight: FontWeight.values[(w ~/ 100) - 1], fontVariations: [FontVariation('wght', w.toDouble())]);

abstract final class Radii {
  static const card = 20.0;
  static const entry = 4.0;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.deco,
    onSecondary: c.todayText,
    error: c.danger,
    onError: brightness == Brightness.dark ? const Color(0xFF3A0A06) : Colors.white,
    surface: c.surface,
    onSurface: c.text,
    surfaceContainerHighest: c.surface2,
    outline: c.border,
    primaryContainer: c.accentSoft,
    onPrimaryContainer: c.text,
  );
  const family = 'NotoSansTC';
  TextStyle s(double size, int w, Color color) => weight(TextStyle(fontFamily: family, fontSize: size, color: color), w);
  final text = TextTheme(
    titleLarge: s(17, 500, c.text),
    titleMedium: s(16, 500, c.text),
    titleSmall: s(14, 500, c.text),
    bodyLarge: s(15, 400, c.text),
    bodyMedium: s(14, 400, c.text),
    bodySmall: s(12, 400, c.text2),
    labelLarge: s(14, 500, c.text),
    labelMedium: s(13, 400, c.text),
    labelSmall: s(11, 400, c.muted),
  );
  final stadium = const StadiumBorder();
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    fontFamily: family,
    textTheme: text,
    extensions: [c],
    dividerColor: c.border,
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: s(16, 500, c.text),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
      titleTextStyle: s(16, 500, c.text),
      contentTextStyle: s(14, 400, c.text),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        minimumSize: const Size(64, 48),
        shape: stadium,
        textStyle: s(14, 500, c.onAccent),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        minimumSize: const Size(64, 48),
        side: BorderSide(color: c.border),
        shape: stadium,
        textStyle: s(14, 500, c.text),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.accent, minimumSize: const Size(48, 48), shape: stadium,
          textStyle: s(14, 500, c.accent)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.accent, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: s(14, 400, c.muted),
      labelStyle: s(14, 400, c.text2),
    ),
    // 選項選中:選中底色 + 主色外框(DESIGN_SYSTEM.md「狀態」)。
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? c.accentSoft : c.surface2),
        foregroundColor: WidgetStateProperty.all(c.text),
        side: WidgetStateProperty.resolveWith(
            (st) => BorderSide(color: st.contains(WidgetState.selected) ? c.accent : c.border, width: st.contains(WidgetState.selected) ? 1.5 : 1)),
        // 不設 textStyle:自訂的 TextStyle(inherit: true)和元件預設的(inherit: false)在狀態動畫時
        // 無法內插,會丟「Failed to interpolate TextStyles with different inherit values」。
        minimumSize: WidgetStateProperty.all(const Size(48, 44)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? c.onAccent : c.text2),
      trackColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? c.accent : c.surface2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.surface2,
      contentTextStyle: s(14, 400, c.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    listTileTheme: ListTileThemeData(iconColor: c.text2, textColor: c.text, minVerticalPadding: 12),
  );
}
