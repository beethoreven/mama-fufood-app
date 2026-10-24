import 'package:characters/characters.dart';
import 'package:uuid/uuid.dart';

/// 使用者看到的字數:一個 emoji(包含 👨‍👩‍👧 這種組合)算一個字。
/// 後端用 Unicode 的字素叢集(\X)算,兩邊規則一致。
int charCount(String text) => text.characters.length;

const _uuid = Uuid();

/// UUID 第 4 版(122 位元亂數,在手機上產生),小寫。紀錄、照片、意見回饋的編號都用它。
String newId() => _uuid.v4().toLowerCase();

final _uuid4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

bool isUuid4(String text) => _uuid4.hasMatch(text);

/// 數量的顯示與換算。內部存「百分之一」的整數(25.5 → 2550)。
abstract final class Amount {
  static String format(int centi) {
    final whole = centi ~/ 100;
    final frac = centi % 100;
    if (frac == 0) return '$whole';
    if (frac % 10 == 0) return '$whole.${frac ~/ 10}';
    return '$whole.${frac.toString().padLeft(2, '0')}';
  }

  /// 使用者輸入的文字 → 百分之一的整數;格式不對或超出 0~999.99 回 null。
  static int? parse(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    final m = RegExp(r'^(\d{1,3})(?:\.(\d{1,2}))?$').firstMatch(t);
    if (m == null) return null;
    final whole = int.parse(m.group(1)!);
    final fracText = (m.group(2) ?? '').padRight(2, '0');
    return whole * 100 + (fracText.isEmpty ? 0 : int.parse(fracText));
  }

  /// 匯出格式的數字:整數就寫整數,否則最多 2 位小數。
  static num toJson(int centi) => centi % 100 == 0 ? centi ~/ 100 : centi / 100;

  /// 匯出檔裡的數字 → 百分之一;不是 0~999.99 或超過 2 位小數回 null。
  static int? fromJson(Object? value) {
    if (value is! num || value is bool) return null;
    final centi = (value * 100).round();
    if ((value * 100 - centi).abs() > 1e-6) return null;
    if (centi < 0 || centi > 99999) return null;
    return centi;
  }
}
