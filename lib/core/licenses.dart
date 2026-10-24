import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// App 自己打包的字型不是 pub 套件,授權不會自動出現在「開放原始碼授權」頁。
/// SIL Open Font License 1.1 規定散布字型時要附上著作權聲明與授權全文,所以在這裡登記
/// (套件的授權由 Flutter 自動收集,不用另外處理)。
void registerBundledLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const ['Noto Sans TC'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
}
