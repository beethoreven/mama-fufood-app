import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';

/// 所有測試共用的設定(flutter test 會自動套用;子資料夾有自己的 flutter_test_config.dart 時用子資料夾的)。
///
/// 截圖比對(test/ui/golden/)不載入真的字型:文字與圖示畫成方塊(Flutter 測試內建的字型),
/// 換一台電腦或升級系統畫出來也一樣,比的是版面(位置、大小、顏色);
/// 比對時再容許各平台反鋸齒與混色的極小差異。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final base = goldenFileComparator;
  if (base is LocalFileComparator) {
    goldenFileComparator = _TolerantComparator(base.basedir.resolve('_'));
  }
  await testMain();
}

/// 容許極小差異的比對:各平台的反鋸齒與混色可能差一兩個色階,版面真的變了則會差很多像素。
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  /// 每個顏色通道(0~255)差這麼多以內算一樣。
  static const channelTolerance = 8;

  /// 不一樣的像素超過這個比例才算失敗(0.2%;360×800 的畫面約 576 個像素)。
  static const maxDiffRatio = 0.002;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenBytes = Uint8List.fromList(await getGoldenBytes(golden));
    final ratio = await _diffRatio(imageBytes, goldenBytes);
    if (ratio <= maxDiffRatio) return true;
    final result = await GoldenFileComparator.compareLists(imageBytes, goldenBytes);
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError('$error\n超過容許的差異:${(ratio * 100).toStringAsFixed(2)}% 的像素不一樣。');
  }

  static Future<double> _diffRatio(Uint8List a, Uint8List b) async {
    final ia = await _decode(a);
    final ib = await _decode(b);
    try {
      if (ia.width != ib.width || ia.height != ib.height) return 1;
      final pa = (await ia.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      final pb = (await ib.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      var bad = 0;
      for (var i = 0; i < pa.length; i += 4) {
        if ((pa[i] - pb[i]).abs() > channelTolerance ||
            (pa[i + 1] - pb[i + 1]).abs() > channelTolerance ||
            (pa[i + 2] - pb[i + 2]).abs() > channelTolerance ||
            (pa[i + 3] - pb[i + 3]).abs() > channelTolerance) {
          bad++;
        }
      }
      return bad / (ia.width * ia.height);
    } finally {
      ia.dispose();
      ib.dispose();
    }
  }

  static Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }
}
