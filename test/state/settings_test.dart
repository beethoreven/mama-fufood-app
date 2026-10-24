import 'package:flutter_test/flutter_test.dart';
import 'package:mama_fufood/core/constants.dart';
import 'package:mama_fufood/data/store.dart';
import 'package:mama_fufood/state/providers.dart';

void main() {
  test('選單秒數：沒設定用預設，0.5～5 秒內的值照用，其他的值用預設', () {
    expect(const AppSettings({}).pickerAutoApply, Timing.pickerAutoApply);
    expect(const AppSettings({}).pickerIdleApply, Timing.pickerIdleApply);
    expect(const AppSettings({Keys.pickerApplyMs: '2500'}).pickerAutoApply, const Duration(milliseconds: 2500));
    expect(const AppSettings({Keys.pickerIdleMs: '5000'}).pickerIdleApply, const Duration(seconds: 5));
    for (final bad in ['0', '400', '700', '5500', 'abc']) {
      expect(AppSettings({Keys.pickerIdleMs: bad}).pickerIdleApply, Timing.pickerIdleApply, reason: bad);
    }
  });
}
