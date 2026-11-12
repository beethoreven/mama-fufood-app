// 版本規則檢查:
// - pubspec.yaml 的 version 是 x.y.z+版本碼,x、y ≤ 99,z ≤ 9。
// - 版本碼 = x×1000 + y×10 + z。
// - x 在重大修改時升;匯出格式的版本另外記在 lib/services/export_format.dart 的 ExportFormat.version,
//   不必等於 x。
//
//     dart run tool/check_version.dart
import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final m = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$', multiLine: true).firstMatch(pubspec);
  if (m == null) _fail('pubspec.yaml 的 version 要寫成 x.y.z+版本碼');
  final x = int.parse(m.group(1)!), y = int.parse(m.group(2)!), z = int.parse(m.group(3)!);
  final code = int.parse(m.group(4)!);
  if (x > 99 || y > 99 || z > 9) _fail('x、y 最大 99,z 最大 9(z 用完就改升 y)');
  final expected = x * 1000 + y * 10 + z;
  if (code != expected) _fail('版本碼應該是 $expected(x×1000 + y×10 + z),現在是 $code');
  stdout.writeln('版本 $x.$y.$z+$code 符合規則');
}

Never _fail(String message) {
  stderr.writeln('版本規則不符:$message');
  exit(1);
}
