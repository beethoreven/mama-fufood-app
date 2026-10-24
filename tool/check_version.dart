// 版本規則檢查(和專案 skill update_version 同一套規則,SPEC 第 2 節):
// - pubspec.yaml 的 version 是 x.y.z+版本碼,x、y ≤ 99,z ≤ 9。
// - 版本碼 = x×1000 + y×10 + z。
// - x 就是匯出格式的版本:lib/services/export_format.dart 的 ExportFormat.version 必須等於 x。
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
  final format = File('lib/services/export_format.dart').readAsStringSync();
  final f = RegExp(r'static const version = (\d+);').firstMatch(format);
  if (f == null) _fail('找不到 ExportFormat.version');
  if (int.parse(f.group(1)!) != x) {
    _fail('主版本號 x($x)必須等於匯出格式版本(${f.group(1)}):只有匯出格式改變時才升 x');
  }
  stdout.writeln('版本 $x.$y.$z+$code 符合規則');
}

Never _fail(String message) {
  stderr.writeln('版本規則不符:$message');
  exit(1);
}
