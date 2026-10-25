/// 限制與數值集中寫成常數,要調整只改這裡。
/// 數值的理由寫在 SPEC_DRAFT.md。
library;

abstract final class Limits {
  /// 每個寶寶每天最多 10 筆(第 4 節)。同步或匯入造成超過時資料保留,只是不能再新增。
  static const recordsPerDay = 10;

  /// 最多 8 個寶寶(第 5 節)。
  static const maxBabies = 8;

  /// 寶寶名稱最多 20 字(一個 emoji 算一個字)。
  static const babyNameMaxChars = 20;

  /// 備註最多 500 字(匯出格式第 5.4 節)。
  static const noteMaxChars = 500;

  /// 每筆紀錄最多 3 張照片。
  static const photosPerRecord = 3;

  /// 準備量、食用量 0~999.99,最多 2 位小數。
  /// 內部以「百分之一」的整數儲存,避免浮點誤差。
  static const amountMaxCenti = 99999;

  /// 月曆的年份範圍(第 7 節)。
  static const yearMin = 2020;
  static const yearMax = 2080;

  /// 意見回饋:描述最多 1000 字、每天最多 3 則、待送清單最多保留 30 天、每天最多自動重試 5 次。
  static const feedbackMaxChars = 1000;
  static const feedbackPerDay = 3;
  static const feedbackQueueDays = 30;
  static const feedbackRetriesPerDay = 5;

  /// 食材名稱一律 3 個字以內(月曆每排放 emoji 加名稱)。後台會檢查,App 只用來排版。
  static const foodNameMaxChars = 3;
}

abstract final class Timing {
  /// 捲動選單放手、停住多久後自動套用並關閉(第 6 節)。這是預設值,使用者可以在 App 設定改。
  static const pickerAutoApply = Duration(milliseconds: 500);

  /// 捲動選單打開後一直沒動,過多久就選定目前停的那一項(通常要的就是第一項或原本的值,不用再點)。
  /// 這是預設值,使用者可以在 App 設定改。
  static const pickerIdleApply = Duration(milliseconds: 1500);

  /// 上面兩個時間在 App 設定裡可以選的範圍:0.5~5 秒,每 0.5 秒一格。
  static final pickerDelayChoices = List<Duration>.unmodifiable([for (var ms = 500; ms <= 5000; ms += 500) Duration(milliseconds: ms)]);

  /// 紀錄介面的選單關掉後,再過這段時間「儲存」才有作用(選單開著時也不能存)。
  static const saveUnlockAfterPicker = Duration(milliseconds: 500);

  /// 換月需拖曳超過一半寬度(只看距離,不看甩動速度)。
  static const monthSwipeFraction = 0.5;

  /// 開 App 或從背景回來時比對雲端版本,一分鐘內不重複(第 4 節)。
  static const syncMinInterval = Duration(minutes: 1);

  /// 同步失敗重試:5 分鐘一次、半天上限 10 次(只在 App 開著時有效)。
  static const syncRetryInterval = Duration(minutes: 5);
  static const syncRetriesPerHalfDay = 10;

  /// 每日檢查失敗:至少間隔 2 小時、一天最多重試 5 次(第 3 節第 3 項)。
  static const dailyCheckRetryGap = Duration(hours: 2);
  static const dailyCheckRetriesPerDay = 5;

  /// 本機診斷記錄只保留一週、記錄檔 2 MB 上限(第 10 節)。
  static const logRetention = Duration(days: 7);
  static const logMaxBytes = 2 * 1024 * 1024;

  /// App 異常關閉後的提示,一天最多跳一次。
  static const crashPromptGap = Duration(days: 1);
}

abstract final class PhotoSpec {
  /// 照片一律重新壓縮成 JPEG:長邊 1280 像素、品質 80,移除拍攝地點等附帶資訊(第 13 節)。
  static const longEdge = 1280;
  static const quality = 80;

  /// 顯示一張只在雲端的照片,最多等這麼久(下載一張約 0.3 MB 的照片);超過就顯示「無法顯示」,
  /// 不讓縮圖一直轉圈。下次打開會再試。
  static const loadTimeout = Duration(seconds: 45);
}

abstract final class FeedbackSpec {
  /// App 端的上限一定小於伺服器的上限(第 10 節):記錄檔原始 ≤2 MB、logcat ≤500 行、
  /// 追蹤資料 ≤512 KB,上傳的壓縮檔 ≤1 MB(伺服器收 1 MiB 壓縮、4 MiB 解壓)。
  static const logcatLines = 500;
  static const traceMaxBytes = 512 * 1024;
  static const uploadMaxCompressed = 1000 * 1000;
}
