# 中文

## 媽媽記副食品 — Android App

寶寶副食品紀錄 App「媽媽記副食品」的 Flutter App(Android 先做,iOS 之後也放在這個 repo)。這份文件分成兩個獨立的部分,請依需求閱讀:

- **[專案報告](#專案報告)**:App 做什麼、資料放在哪裡、同步與加密怎麼設計、踩過哪些坑 —— 給想了解「這是什麼」的人看。
- **[架設 SOP](#架設-sop)**:開發環境、跑測試、打包與安裝要填的設定 —— 給想「動手把它跑起來」的人看。

這兩部分刻意分開,不要交叉閱讀;報告是背景知識,SOP 是操作手冊。

程式註解裡的「SPEC 第 N 節」、`SPEC_DRAFT.md`、`EXPORT_FORMAT_DRAFT.md`、`DESIGN_SYSTEM.md`、`tools/*.py` 等,是只留在開發者本機的規格、設計文件與工具,不在 repo 裡。

---

## 專案報告

### 這是什麼

給新手爸媽記錄寶寶副食品的 App:每次吃了什麼、準備多少、吃了多少、有沒有過敏狀況、寶寶喜不喜歡,整理成三個頁籤:

- **行事曆**:月曆上每一天最多三排「emoji + 食材名稱」,點一天看當天的清單或直接新增。
- **統計**:依分組列出每種食材在一段期間內的食用量。
- **食材判斷**:依固定規則把紀錄整理成「過敏」與「喜好」的圖示。**這不是醫療判斷**,各介面都會提醒「僅供記錄與參考,非基於醫學知識做的判斷」與「任何反應請諮詢醫師」;規則完整公開在 App 的「判斷邏輯說明」頁。

另外有多個寶寶(最多 8 個)、雲端同步、照片、加密匯出與匯入、意見回饋。預設深色模式,因為常在深夜哄睡之後記錄。

### 系統架構

整個專案是一個 git meta-repo(`mama-fufood`)透過 submodule 掛載三個獨立 repo:

```
mama-fufood/                     ← meta-repo,本機開發統一入口,本身不部署
├── mama-fufood-app/             ← 本 repo,Flutter Android App,本機打包、用 adb 安裝
├── mama-fufood-backend/         ← 後端 API,部署到 Render(Flask + gunicorn)
└── mama-fufood-web/             ← 網站與管理後台,部署到 GitHub Pages
```

Dart 的套件名稱是 `mama_fufood`(程式裡 `package:mama_fufood/...` 的 import),和資料夾名稱不同,因為 Dart 套件名稱只能用小寫字母、數字與底線。

App 連到的地方:

| 對象 | 做什麼 |
|---|---|
| 手機本機的資料庫(SQLite,用 drift) | 所有紀錄,一定先存這裡;斷網照常使用 |
| 使用者自己的 Google 雲端硬碟 | 紀錄同步(App 專用區,使用者看不到)、照片(看得到的「媽媽記副食品/照片」資料夾)、匯出檔與它的金鑰 |
| 後端(`mama-fufood-backend`) | 每天一次的版本與公用資料檢查、意見回饋、匯入舊格式檔時的格式轉換。**不送任何寶寶資料** |

### 離線優先:紀錄永遠先存在手機

- 每筆紀錄有 UUID 與最後修改時間;刪除用「標記」而不是真的刪掉,否則同步時另一支手機會把它「復活」。
- 時間存 UTC,同時存記錄當下的時區偏移(例如 +08:00)。月曆上的日期 = UTC 加上那個偏移,出國時打開也不會跑到前一天。
- 數量用「百分之一」的整數存(0~999.99,最多 2 位小數),避免浮點誤差。
- 使用者訂的限制都集中在 `lib/core/constants.dart`:每個寶寶每天最多 10 筆、最多 8 個寶寶、名稱最多 20 字(一個 emoji 算一個字)、備註最多 500 字、每筆最多 3 張照片。
- Android 自動備份只備份資料庫的資料夾(`files/db/`):照片、診斷記錄、待送的意見回饋都不備份。自動備份每個 App 上限 25 MB,超過就整份不備份,所以照片要靠「照片存到雲端」保護。

### 雲端同步:每筆紀錄一個檔

同步用使用者自己雲端硬碟的 App 專用區(`drive.appdata` 權限),我們的伺服器看不到。Google 雲端硬碟沒有「條件式更新」(比對版本後才寫入),兩支手機同時寫同一個檔就會互蓋,所以:

- **每筆紀錄一個檔**(`mff_rec_{UUID}.json`),另外有寶寶清單與版本檔。衝突的範圍縮小到「同一筆紀錄兩邊都改了」。每個檔的屬性帶最後修改時間、是否刪除、屬於哪個寶寶,不用下載內容就能比對。
- **三種情況**:雲端版本等於上次同步的版本 → 沒人動過,直接上傳,再讀一次確認;雲端版本等於上次「要寫」的版本 → 上次其實已經傳成功;其他 → 有人動過,逐筆比對,沒衝突的自動合併,有衝突的才問使用者(保留較新的 / 手機上的 / 雲端的 / 先停止同步)。
- **沒成功絕不刪本機**:雲端少了檔案也不刪手機上的紀錄。
- 失敗重試:5 分鐘一次、半天最多 10 次,只在 App 開著時。每個雲端硬碟的呼叫最多等 60 秒(上傳下載照片與匯出檔 30 分鐘),整輪同步最多 10 分鐘,不會卡住。
- 以「一支手機為主」設計;第二支手機造成的衝突只求堪用。

### 匯出檔整份加密,金鑰在使用者自己的雲端硬碟

匯出檔(`.mff`)存到使用者雲端硬碟的「媽媽記副食品」資料夾,裡面是寶寶的名稱、紀錄與照片,所以整份加密:

- **格式**:檔頭(`MAMAFF` 識別字 + 長度 + JSON:格式版本、App 版本、匯出時間、金鑰代號、加密方式)+ 以 1 MiB 為一段的 AES-256-GCM 密文。每段的 nonce = 8 bytes 的隨機前綴 + 4 bytes 的段落序號,並把整個檔頭與「是不是最後一段」當成附加驗證資料,所以檔頭被改、段落被調換或截斷都解不開。
- **金鑰**:一個 Google 帳號一把 256 位元的金鑰,存在該帳號雲端硬碟的 App 專用區,我們拿不到,也沒辦法幫忙解開。建立前一定先查有沒有既有的;**只有雲端硬碟明確回答「沒有」才建立**,讀取失敗(例如斷網)一律當作錯誤。兩支手機剛好同時第一次匯出、各建了一把時,兩把都保留,之後一律用建立時間最早的那把;匯入時依檔頭的金鑰代號找,使用者不用分。
- **匯出完立刻驗證**:把剛上傳的檔下載回來、解密、核對筆數與照片;驗證失敗就刪掉那個檔並告訴使用者,不會留下一個打不開的備份。
- 格式改版時,舊檔由後端逐版轉換成新格式(轉完就丟,不保存)。

### 照片

- 用系統的照片挑選器,不需要讀取全部相簿的權限。
- 一律重新壓縮成 JPEG:長邊 1280 像素、品質 80,依方向資訊轉正,並移除拍攝地點等附帶資訊(Samsung 的 HEIF 也轉成 JPEG)。估計一張約 150~250 KB。
- 開啟「照片存到雲端」時,照片上傳到使用者看得到的「媽媽記副食品/照片」資料夾(`drive.file` 權限:只能存取 App 自己建立的檔案),**上傳成功後才刪掉手機上的那一份**。關掉這個開關時,雲端上的照片保留。

### 判斷規則寫死在 App 裡

過敏與喜好的規則(`lib/domain/judgement.dart`)直接寫在 App 裡,不從後端下載:要改規則就發新版 App,而且「判斷邏輯說明」頁的文字要在同一版一起改,說明與實際行為才不會不一致。

- **過敏**:沒有 0 分、隔天發生 0.3 分、當天發生 1 分,平均 0.2 以下「穩定」、0.7 以下「風險」、以上「過敏」;另有最低標示(任一筆當天 → 至少風險;兩筆以上隔天 → 至少風險;兩筆以上當天 → 過敏)。
- **喜好**:排斥 -1、接受 0、喜歡 1,取「最近 10 筆」與「近 3 個月」中筆數較多的一組。
- 紀錄不足時**不放圖示**,位置留空,代表還不能判斷。分數一律用整數算,避免浮點誤差。

### 診斷記錄與當機捕捉

- 記錄檔只收事件代碼、數字與選項值,不收自由文字;不記寶寶名稱、備註與紀錄內容(連吃了哪種食材都不記)。只保留 7 天、總共 2 MB。
- 使用者在意見回饋選「遇到問題」才附上記錄檔、logcat 摘錄與上次異常結束的原因。送出前在手機上遮蔽:Email、登入憑證、網址的查詢參數、檔名、引號內的文字、寶寶名稱、帳號的顯示名稱、電話、IP、裝置識別碼、雲端硬碟的檔案編號(`AppLog.redact`,有測試)。
- 機型、電量、網路類型、儲存空間這些除錯資訊由 App 自己的原生程式取得(`DiagnosticsChannel.kt`),只取需要的那幾項;**不取** IMEI、序號、廣告 ID、位置、其他 App 清單。原生層當機寫進一個檔,下次開啟時讀出來。
- 最低支援 Android 11(API 30):選的 emoji 要 Android 11 才能完整顯示,讀「上次結束原因」(`ApplicationExitInfo`)也要 Android 11。
- 除錯工具(故意當機、故意無回應)只在 debug 版出現,release 版在編譯時就移除。

### 正式版一定要用自己的金鑰簽

正式版(release)的簽署金鑰非常重要:**裝到手機之後,之後的每一版都要用同一把簽**,否則只能先解除安裝(手機上的資料會不見)。所以 `android/app/build.gradle.kts` 在沒有 `android/key.properties` 時,打包正式版會直接停下來並說明原因,避免不小心用除錯金鑰簽出一版裝到要長期使用的手機上。只想在自己的模擬器上試 release 版時,可以設環境變數 `MFF_ALLOW_DEBUG_SIGNING=1`。

### 套件版本的取捨

所有套件釘在 2026-10-23 當下的最新正式版(`pubspec.yaml`),Flutter 也釘在 3.47.7。例外與原因都寫在 `pubspec.yaml` 旁邊:

- `build_runner` 停在 2.16.2:最新的 2.17.1 需要 `build` 5,但最新的 `drift_dev` 2.35.1 只支援 `build` 4;2.17.0 已被撤回。
- 不用 `device_info_plus`、`battery_plus`、`connectivity_plus`:後兩者的最新版彼此衝突(都綁了不同版本的 `dbus`),而且需要的欄位只有幾個,改由自己的原生程式取得。
- `file_picker` 13 的寫法改成靜態的 `FilePicker.pickFiles`(舊的 `FilePicker.platform` 已經沒有了)。

### 畫面測試抓到的問題

`test/ui/` 對每個主要畫面 × 三種螢幕(320×640、360×800、412×915 dp)× 兩種字級(預設、大一級 1.15 倍)檢查版面與觸控目標,第一次跑就抓到:

- **小螢幕的月曆格子爆版**:放三排紀錄的日子底部超出 10~18 px。改成三排平分日期下方的高度,放得下就用原本的大小,放不下才一起縮小。
- **觸控目標不到 48 dp**:年月選擇鈕與選項膠囊 44 dp、頂部的寶寶切換 39 dp、判斷圖示 34 dp,都改成 48 dp(圖示本身的大小不變,只放大點得到的範圍)。
- 唯一的例外:不到 336 dp 寬的螢幕,月曆一列 7 格放不下 48 dp 寬(320 dp 時每格 45.7 dp,高度仍有 72 dp 左右),測試對月曆格子只要求「螢幕寬 ÷ 7」。

測試本身也踩過坑:Flutter 的 `rootBundle` 會快取讀過的檔案,而快取的結果綁在上一個測試的假時鐘上,不清掉的話,第二個測試起畫面永遠是空白的;另外,一開始只檢查「沒有錯誤」,空白畫面也會通過,所以每個情境都另外確認「真的走到了那個畫面」。

### 其他踩過的坑

- **設定頁整頁紅色錯誤**:`SegmentedButton` 的主題設了 `textStyle`,和預設樣式的 `inherit` 不一致,切換時無法做動畫插值(`Failed to interpolate TextStyles with different inherit values`);同一頁另一個錯誤是把 `SegmentedButton` 放在 `ListTile` 的 `trailing`,它吃掉整列的寬度。拿掉 `textStyle`,並把按鈕移到 `subtitle`。
- **判斷邏輯說明頁永遠在轉圈**:讀檔的 `Future` 寫在 `build` 裡,每次重畫都重新開始。改成在 State 裡只建立一次。
- **drift 產生的類別撞名**:資料列的類別叫 `Record` 會和 Dart 內建的 Record 型別撞名、`Baby` 會和畫面用的類別撞名,所以資料列一律加 `Row`(`RecordRow`、`BabyRow`)。
- **模擬器用無頭模式(swiftshader)畫不出第一個畫面**:CPU 吃到 290%、一直停在黑畫面;改用 `-gpu host` 開視窗就正常。

### 檔案結構

```
lib/
  core/       常數(使用者訂的限制都在 constants.dart)、時間、記錄檔與遮蔽、建置時的設定
  domain/     判斷規則(寫死在 App)、統計、月曆排法、食材清單與紀錄的模型
  data/       本機資料庫(drift)與讀寫;database.g.dart 是產生出來的
  services/   Google 登入、後端、雲端同步、照片、匯出加密與匯入、意見回饋、除錯資訊
  state/      Riverpod 的 provider
  ui/         畫面:主畫面框架、行事曆、新增與檢視紀錄、統計、食材判斷、更多選單的各頁
assets/
  datasets/   內建的公用資料(食材清單、單位;和後端第一次建表用的是同一份)
  texts/      使用者條款、隱私權政策、判斷邏輯說明、資料運用原則(和網站的是同一份)
  fonts/      Noto Sans TC 可變字型與它的授權條款(OFL)
android/      套件名稱 tw.com.tutorarthur.mamafufood;除錯資訊與當機捕捉(Kotlin);備份規則
test/
  domain/     判斷規則、統計、月曆
  services/   雲端同步(用假的雲端跑兩支手機的情境)、匯出格式與加密
  core/       診斷資料的遮蔽
  ui/         畫面測試:layout/(版面與觸控目標,真字型)、golden/(截圖比對)
tool/check_version.dart   版本號規則檢查
```

`assets/datasets/` 與 `assets/texts/` 是從規格文件產生的(和後端、網站的是同一份),不要直接改。

### 已知限制

- **Google 登入、每日檢查、雲端同步、照片上雲、匯出與匯入、意見回饋,還沒有在真的 Google Cloud 與後端上跑過**:這些要等 meta repo README 的上線 SOP 做完才能驗證。目前驗證過的是模擬器上的本機功能(月曆、新增與檢視紀錄、統計、食材判斷、設定、寶寶管理、說明頁)和 release 版能正常開啟。
- iOS 還沒做;第 4 個頁籤先空著。目前是上架前的 0.x 版,匯出格式是第 0 版;第 4 個頁籤做成「腹瀉嘔吐」時,匯出格式改成第 1 版,App 升到 1.0.0,第 0 版的匯出檔匯入時由後端轉換。
- 320 dp 寬的小螢幕,月曆格子寬 45.7 dp,不到 48 dp(見上方畫面測試);放三排的格子在大一級字時字比較小,要在實機上再看一次是否看得清楚。
- release 版不把記錄印到 logcat,要看記錄只能透過意見回饋。
- 雲端同步以一支手機為主,兩支手機同時改同一筆時會請使用者選擇。
- **打包時 Flutter 警告 `cryptography_flutter`、`flutter_image_compress_common` 兩個外掛還在用舊的 Kotlin 設定(KGP),將來的 Flutter 版本會因此打包失敗。** 目前兩個都已經是最新版(2.3.4、1.1.1),沒有可以升級的版本,所以先不動。升級 Flutter 前先看這兩個外掛有沒有出新版;如果還是沒有:`cryptography_flutter` 可以拿掉(匯出加密會改用純 Dart 的實作,功能一樣、只是比較慢),`flutter_image_compress` 要找替代套件。

---

# 架設 SOP / Setup Guide

## Part A. 開發環境

### 1. 安裝 Flutter 3.47.7

這個 repo 釘在 Flutter **3.47.7**(`pubspec.yaml` 的 `environment.flutter`)。照 [Flutter 官方的 macOS 安裝說明](https://docs.flutter.dev/get-started/install/macos) 裝到 `~/development/flutter`,切到這個版本,然後讓終端機找得到它:

```bash
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc
```

關掉終端機再打開,執行 `flutter --version`,應該顯示 3.47.7。

### 2. 安裝 Android SDK 與模擬器

裝 [Android Studio](https://developer.android.com/studio),在 **SDK Manager** 裝好 Android SDK、Platform Tools(裡面有 `adb`)與一個模擬器映像檔,然後執行 `flutter doctor`,照它的提示補齊(例如 `flutter doctor --android-licenses`)。

模擬器要用 `-gpu host` 開視窗(無頭模式畫不出第一個畫面):

```bash
~/Library/Android/sdk/emulator/emulator -avd <模擬器名稱> -gpu host
```

### 3. 取得套件並執行

```bash
cd mama-fufood-app
flutter pub get
flutter run
```

這樣跑起來的 App 可以在手機上記錄,但登入、檢查更新、意見回饋會顯示「還沒設定」。要連上後端與 Google 登入,先照 Part D 建立 `env/prod.json`,再:

```bash
flutter run --dart-define-from-file=env/prod.json
```

### 4. 改了資料庫的定義之後

`lib/data/database.dart` 改了之後,要重新產生 `database.g.dart`:

```bash
dart run build_runner build
```

---

## Part B. 跑測試

```bash
flutter analyze
flutter test
dart run tool/check_version.dart
```

- `flutter test` 目前 193 項,其中畫面測試(`test/ui/`)是每個主要畫面 × 三種螢幕 × 兩種字級。
- `tool/check_version.dart` 檢查版本號:App 版本 x.y.z 的 x 只在匯出格式改變時動,Android 版本碼 = x×1000 + y×10 + z。

截圖比對(`test/ui/golden/`)的文字畫成方塊,在不同電腦上畫出來才會一樣。**故意改了版面時**,重新產生截圖、看過再提交:

```bash
flutter test test/ui/golden --update-goldens
```

想看實際的樣子(真字型,存到 `test/ui/layout/shots/`,不進 git):

```bash
flutter test test/ui/layout --dart-define=MFF_SHOTS=true --update-goldens
```

---

## Part C. 打包正式版、安裝到手機

正式版要填後端網址與 Google 用戶端 ID,簽署金鑰的 SHA-1 也要登記到 Google Cloud,所以完整的上線步驟集中寫在 meta repo [`mama-fufood`](https://github.com/beethoreven/mama-fufood) README 的「上線 SOP」,照那份的順序做。

只想在自己的模擬器上試 release 版(不裝到別人手機)時,不需要正式的金鑰:

```bash
MFF_ALLOW_DEBUG_SIGNING=1 flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**這樣簽出來的版本不要裝到要長期使用的手機上**:之後換成正式金鑰簽的版本會裝不上去,只能解除安裝(資料會不見)。

---

## Part D. 設定值總覽

**`env/prod.json`**(不進 git;格式見 `env/prod.example.json`;建置時用 `--dart-define-from-file=env/prod.json` 帶入,不是秘密):

| 欄位 | 必填? | 說明 |
|---|---|---|
| `MFF_API_BASE` | **必填**(要用連網功能時) | 後端網址,例如 `https://mama-fufood-backend.onrender.com`,**結尾不要斜線**。沒填時,檢查更新、意見回饋顯示「這個版本還沒設定後端網址」。 |
| `MFF_WEB_CLIENT_ID` | **必填**(要用 Google 登入時) | Google Cloud「網頁應用程式」用戶端 ID(和後端的 `GOOGLE_CLIENT_ID` 是同一個)。Android 用戶端的 ID 不用填,Google 用套件名稱加 SHA-1 對應。 |

**`android/key.properties`**(不進 git;正式版的簽署金鑰):

| 欄位 | 說明 |
|---|---|
| `storePassword` | 金鑰庫的密碼 |
| `keyPassword` | 金鑰的密碼(用 `keytool` 建立時通常和上面一樣) |
| `keyAlias` | 金鑰的別名,例如 `upload` |
| `storeFile` | 金鑰檔的**完整路徑**,例如 `/Users/<你的帳號>/Keys/mama-fufood/upload-keystore.jks` |

**環境變數:**

| 變數 | 說明 |
|---|---|
| `MFF_ALLOW_DEBUG_SIGNING` | 設成 `1` 時,沒有 `key.properties` 也能打包正式版(用除錯金鑰簽,只給自己的模擬器用)。 |

---

# English

## Mama's Baby Food Log — Android App

The Flutter app for *媽媽記副食品* ("Mama's Baby Food Log"), an app for logging a baby's complementary food (Android first; iOS will live in this repo too later). This document is split into two independent parts — read whichever fits what you need:

- **[Project Report](#project-report)**: what the app does, where the data lives, how sync and encryption are designed, and the pitfalls hit along the way — for anyone who wants to understand "what is this."
- **[Setup Guide](#setup-guide)**: the development environment, running the tests, and the settings needed to build and install — for anyone who wants to "get it running."

These two parts are deliberately kept separate — don't read them interleaved; the report is background knowledge, the guide is an operating manual.

References in code comments such as "SPEC 第 N 節" (SPEC section N), `SPEC_DRAFT.md`, `EXPORT_FORMAT_DRAFT.md`, `DESIGN_SYSTEM.md` and `tools/*.py` point to specs, design documents and tools that live only on the developer's machine; they are not in this repo.

## Project Report

### What This Is

An app for new parents to log their baby's complementary food — what the baby ate each time, how much was prepared, how much was eaten, whether there was an allergic reaction, and whether the baby liked it — organized into three tabs:

- **Calendar**: each day shows up to three rows of "emoji + food name"; tap a day to see that day's list or add a record directly.
- **Statistics**: the amount eaten of each food over a period, grouped by food group.
- **Food judgement**: records summarized by fixed rules into "allergy" and "preference" icons. **This is not a medical judgement**; every screen reminds the user that it is "for record-keeping and reference only, not a judgement based on medical knowledge" and "consult a doctor about any reaction"; the rules are fully published on the app's "判斷邏輯說明" (judgement-logic guide) page.

There are also multiple babies (up to 8), cloud sync, photos, encrypted export and import, and feedback. Dark mode is the default, because records are often made late at night after getting the baby to sleep.

### System Architecture

The whole project is a git meta-repo (`mama-fufood`) that wraps three independent repos via submodules:

```
mama-fufood/                     ← meta-repo, unified local-dev entry point, never deployed itself
├── mama-fufood-app/             ← this repo, Flutter Android app, built locally and installed via adb
├── mama-fufood-backend/         ← backend API, deployed to Render (Flask + gunicorn)
└── mama-fufood-web/             ← website and admin console, deployed to GitHub Pages
```

The Dart package name is `mama_fufood` (the `package:mama_fufood/...` imports in the code), different from the folder name, because Dart package names may only use lowercase letters, digits and underscores.

What the app talks to:

| Party | What for |
|---|---|
| The phone's local database (SQLite via drift) | Every record is always saved here first; works fully offline |
| The user's own Google Drive | Record sync (the app-only area, invisible to the user), photos (the visible "媽媽記副食品/照片" folder), export files and their key |
| The backend (`mama-fufood-backend`) | The once-a-day version and public-data check, feedback, and format conversion when importing an old-format file. **No baby data is ever sent** |

### Offline First: Records Always Live on the Phone First

- Every record has a UUID and a last-modified time; deletion sets a "deleted" mark instead of really removing it, otherwise sync would let another phone "resurrect" it.
- Times are stored in UTC together with the time-zone offset at recording time (e.g. +08:00). The calendar date = UTC plus that offset, so opening the app abroad doesn't push records to the previous day.
- Amounts are stored as integers in hundredths (0–999.99, at most 2 decimal places) to avoid floating-point error.
- User-defined limits are all in `lib/core/constants.dart`: at most 10 records per baby per day, at most 8 babies, names at most 20 characters (an emoji counts as one), notes at most 500 characters, at most 3 photos per record.
- Android Auto Backup only backs up the database folder (`files/db/`): photos, diagnostic logs and queued feedback are not backed up. Auto Backup has a 25 MB cap per app and skips everything beyond it, so photos must be protected by "照片存到雲端" (save photos to the cloud).

### Cloud Sync: One File per Record

Sync uses the app-only area of the user's own Google Drive (the `drive.appdata` scope), which our server can't see. Google Drive has no conditional update (write only if the version still matches), so two phones writing the same file at the same time overwrite each other. Therefore:

- **One file per record** (`mff_rec_{UUID}.json`), plus a baby list and a version file. Conflicts shrink to "both sides changed the same record". Each file's properties carry the last-modified time, the deleted flag and which baby it belongs to, so files can be compared without downloading their content.
- **Three cases**: the cloud version equals the version from the last sync → nobody touched it, so upload and read back to confirm; the cloud version equals the version we last *tried* to write → the last upload actually succeeded; otherwise → someone changed things, so compare record by record, merge whatever doesn't conflict automatically, and only ask the user about conflicts (keep the newer one / the phone's / the cloud's / stop syncing for now).
- **Never delete local data without success**: files missing in the cloud never delete records on the phone.
- Retry on failure: every 5 minutes, at most 10 times per half day, only while the app is open. Each Google Drive call waits at most 60 seconds (30 minutes for photo and export transfers), and a whole sync round at most 10 minutes, so nothing hangs forever.
- Designed around one main phone; conflicts caused by a second phone only need to be good enough.

### Export Files Are Fully Encrypted, with the Key in the User's Own Drive

Export files (`.mff`) go into the "媽媽記副食品" folder of the user's Google Drive and contain the baby's name, records and photos, so the whole file is encrypted:

- **Format**: a header (the `MAMAFF` magic + length + JSON: format version, app version, export time, key ID, cipher) followed by AES-256-GCM ciphertext in 1 MiB segments. Each segment's nonce = an 8-byte random prefix + a 4-byte segment index, and the whole header plus a "this is the last segment" flag are bound in as additional authenticated data, so a modified header, reordered segments or a truncated file all fail to decrypt.
- **Key**: one 256-bit key per Google account, stored in that account's Drive app-only area; we can't get it and can't help decrypt. Before creating one the app always checks for an existing key; **it only creates one when Drive explicitly answers "none"**, and any read failure (e.g. offline) is treated as an error. If two phones happen to export for the first time simultaneously and each creates a key, both are kept and the earliest-created one is used from then on; imports look the key up by the ID in the header, so the user never has to choose.
- **Verified right after export**: the just-uploaded file is downloaded again, decrypted, and its record and photo counts checked; if verification fails the file is deleted and the user is told, so no unopenable backup is left behind.
- When the format changes, old files are converted version by version by the backend (and discarded right after, never stored).

### Photos

- Uses the system photo picker, so no permission to read the whole gallery is needed.
- Always re-compressed to JPEG: long edge 1280 px, quality 80, rotated upright from the orientation tag, with location and other metadata removed (Samsung's HEIF is converted to JPEG too). Roughly 150–250 KB per photo.
- With "照片存到雲端" (save photos to the cloud) on, photos are uploaded to the user-visible "媽媽記副食品/照片" folder (the `drive.file` scope: access only to files the app created), and **the phone's copy is deleted only after the upload succeeds**. Turning the switch off leaves the cloud photos in place.

### The Judgement Rules Are Hard-Coded in the App

The allergy and preference rules (`lib/domain/judgement.dart`) are written into the app itself rather than downloaded from the backend: changing them means shipping a new app version, and the "判斷邏輯說明" (judgement-logic guide) page text must change in the same version, so the explanation and the actual behavior never disagree.

- **Allergy**: none 0, next-day reaction 0.3, same-day reaction 1; an average up to 0.2 is "stable", up to 0.7 "risk", above that "allergic"; plus minimum labels (any same-day reaction → at least "risk"; two or more next-day reactions → at least "risk"; two or more same-day reactions → "allergic").
- **Preference**: reject -1, accept 0, like 1, using whichever of "the latest 10 records" and "the last 3 months" has more records.
- With too few records **no icon is shown** — the spot stays empty, meaning "can't tell yet". All scores are computed with integers to avoid floating-point error.

### Diagnostic Logs and Crash Capture

- The log file only records event codes, numbers and option values, never free text; no baby names, notes or record contents (not even which food was eaten). Kept 7 days, 2 MB in total.
- Only when the user picks "遇到問題" (ran into a problem) in feedback are the log file, a logcat excerpt and the reason for the last abnormal exit attached. They are masked on the phone before sending: emails, sign-in credentials, URL query strings, file names, quoted text, baby names, the account's display name, phone numbers, IPs, device identifiers and Google Drive file IDs (`AppLog.redact`, with tests).
- Debug information such as device model, battery, network type and storage is read by the app's own native code (`DiagnosticsChannel.kt`), only the fields that are needed; it **never** reads the IMEI, serial number, advertising ID, location or the list of other apps. A native-layer crash is written to a file and read back on the next launch.
- Minimum Android 11 (API 30): the chosen emoji need Android 11 to display fully, and reading "the reason for the last exit" (`ApplicationExitInfo`) also needs Android 11.
- Debug tools (deliberate crash, deliberate hang) only exist in debug builds; release builds remove them at compile time.

### Release Builds Must Be Signed with Your Own Key

The release signing key is critical: **once a build is installed on a phone, every later version must be signed with the same key**, or the only way forward is uninstalling (which deletes the phone's data). So `android/app/build.gradle.kts` stops a release build with an explanation when `android/key.properties` is missing, so a debug-key-signed build can't accidentally end up on the phone that will use it long-term. To try a release build on your own emulator only, set the environment variable `MFF_ALLOW_DEBUG_SIGNING=1`.

### Dependency Version Trade-offs

Every package is pinned to the latest stable release as of 2026-10-23 (`pubspec.yaml`), and Flutter is pinned to 3.47.7. The exceptions and their reasons are written next to them in `pubspec.yaml`:

- `build_runner` stays at 2.16.2: the latest 2.17.1 needs `build` 5, but the latest `drift_dev` 2.35.1 only supports `build` 4; 2.17.0 was retracted.
- No `device_info_plus`, `battery_plus` or `connectivity_plus`: the latest versions of the last two conflict (they pin different `dbus` versions), and only a few fields are needed, so the app's own native code reads them.
- `file_picker` 13 is used through the static `FilePicker.pickFiles` (the old `FilePicker.platform` is gone).

### Problems the Screen Tests Caught

`test/ui/` checks layout and touch targets for every main screen × three screen sizes (320×640, 360×800, 412×915 dp) × two text sizes (default, one step larger at 1.15×). The very first run caught:

- **Calendar cells overflowing on the small screen**: days with three rows of records overflowed the bottom by 10–18 px. The three rows now share the height below the date: natural size when they fit, all shrinking together when they don't.
- **Touch targets under 48 dp**: the year/month pickers and option chips were 44 dp, the baby switcher at the top 39 dp, the judgement icons 34 dp — all now 48 dp (the icons themselves stay the same size; only the tappable area grew).
- The one exception: on screens narrower than 336 dp a row of 7 calendar cells can't be 48 dp wide each (45.7 dp at 320 dp wide, while still about 72 dp tall), so the test only requires "screen width ÷ 7" for calendar cells.

The tests hit their own pitfalls too: Flutter's `rootBundle` caches files it has read, and the cached result is tied to the previous test's fake clock, so without clearing it every test from the second one on showed a permanently blank screen; also, the first version only checked "no errors", so a blank screen passed too — every scenario now also confirms "we really reached that screen".

### Other Pitfalls Hit Along the Way

- **The settings page turned into a full red error screen**: the `SegmentedButton` theme set a `textStyle` whose `inherit` didn't match the default style, so the switching animation couldn't interpolate (`Failed to interpolate TextStyles with different inherit values`); a second error on the same page came from putting a `SegmentedButton` in a `ListTile`'s `trailing`, where it took up the whole row's width. The `textStyle` was removed and the buttons moved to `subtitle`.
- **The judgement-logic guide page spun forever**: the `Future` that reads the file was created inside `build`, restarting on every rebuild. It is now created once in the State.
- **Class names generated by drift collided**: a row class called `Record` clashes with Dart's built-in Record type and `Baby` with the UI's class, so row classes always get a `Row` suffix (`RecordRow`, `BabyRow`).
- **The emulator in headless mode (swiftshader) never drew the first frame**: CPU at 290% and stuck on a black screen; opening it in a window with `-gpu host` works fine.

### File Layout

```
lib/
  core/       constants (all user-defined limits are in constants.dart), time, logging and masking, build-time settings
  domain/     judgement rules (hard-coded in the app), statistics, calendar layout, food-list and record models
  data/       local database (drift) and access; database.g.dart is generated
  services/   Google sign-in, backend, cloud sync, photos, export encryption and import, feedback, diagnostics
  state/      Riverpod providers
  ui/         screens: the main shell, calendar, adding and viewing records, statistics, food judgement, the "more" menu's pages
assets/
  datasets/   built-in public data (food list, units; identical to what the backend seeds on first start)
  texts/      terms of use, privacy policy, judgement-logic guide, data-use principles (identical to the website's)
  fonts/      the Noto Sans TC variable font and its license (OFL)
android/      package name tw.com.tutorarthur.mamafufood; diagnostics and crash capture (Kotlin); backup rules
test/
  domain/     judgement rules, statistics, calendar
  services/   cloud sync (two-phone scenarios against a fake cloud), export format and encryption
  core/       masking of diagnostic data
  ui/         screen tests: layout/ (layout and touch targets, real fonts), golden/ (screenshot comparison)
tool/check_version.dart   version-number rule check
```

`assets/datasets/` and `assets/texts/` are generated from the spec documents (identical to the backend's and the website's copies) — don't edit them directly.

### Known Limitations

- **Google sign-in, the daily check, cloud sync, photo upload, export and import, and feedback have not run against a real Google Cloud project and backend yet**: they can only be verified once the meta repo README's Setup Guide is done. What has been verified is the local functionality on an emulator (calendar, adding and viewing records, statistics, food judgement, settings, baby management, the guide pages) and that the release build launches normally.
- iOS isn't done yet; the 4th tab is a placeholder for now. This is the pre-release 0.x line with export format 0; when the 4th tab becomes "diarrhea and vomiting", the export format becomes version 1 and the app 1.0.0, and format-0 export files are converted by the backend on import.
- On a 320 dp wide screen, calendar cells are 45.7 dp wide, under 48 dp (see the screen tests above); cells with three rows use small text at the larger text size — worth checking on a real phone for legibility.
- Release builds don't print logs to logcat; logs can only be seen through feedback.
- Cloud sync is designed around one main phone; when two phones change the same record at the same time, the user is asked to choose.
- **When building, Flutter warns that the `cryptography_flutter` and `flutter_image_compress_common` plugins still use the old Kotlin setup (KGP), which future Flutter versions will refuse to build.** Both are already at their latest versions (2.3.4, 1.1.1), with nothing newer to upgrade to, so they stay for now. Before upgrading Flutter, check whether either plugin has a new release; if not, `cryptography_flutter` can be dropped (export encryption falls back to the pure-Dart implementation — same result, just slower), and `flutter_image_compress` needs a replacement package.

---

# Setup Guide

## Part A. Development Environment

### 1. Install Flutter 3.47.7

This repo is pinned to Flutter **3.47.7** (`environment.flutter` in `pubspec.yaml`). Follow [Flutter's official macOS install guide](https://docs.flutter.dev/get-started/install/macos) to install it into `~/development/flutter`, switch to this version, then make the terminal find it:

```bash
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc
```

Close and reopen the terminal and run `flutter --version`; it should print 3.47.7.

### 2. Install the Android SDK and an Emulator

Install [Android Studio](https://developer.android.com/studio), use its **SDK Manager** to install the Android SDK, Platform Tools (which contain `adb`) and an emulator image, then run `flutter doctor` and follow its hints (e.g. `flutter doctor --android-licenses`).

Open the emulator in a window with `-gpu host` (headless mode never draws the first frame):

```bash
~/Library/Android/sdk/emulator/emulator -avd <emulator name> -gpu host
```

### 3. Get the Packages and Run

```bash
cd mama-fufood-app
flutter pub get
flutter run
```

The app started this way can log records on the phone, but sign-in, update checks and feedback show "還沒設定" (not configured yet). To connect to the backend and Google sign-in, create `env/prod.json` per Part D first, then:

```bash
flutter run --dart-define-from-file=env/prod.json
```

### 4. After Changing the Database Definition

After changing `lib/data/database.dart`, regenerate `database.g.dart`:

```bash
dart run build_runner build
```

---

## Part B. Run the Tests

```bash
flutter analyze
flutter test
dart run tool/check_version.dart
```

- `flutter test` currently runs 193 tests; the screen tests (`test/ui/`) cover every main screen × three screen sizes × two text sizes.
- `tool/check_version.dart` checks the version number: the x in app version x.y.z only changes when the export format changes, and the Android version code = x×1000 + y×10 + z.

The screenshot comparison (`test/ui/golden/`) draws text as boxes so that different machines render identically. **When you change a layout on purpose**, regenerate the screenshots and review them before committing:

```bash
flutter test test/ui/golden --update-goldens
```

To see what it really looks like (real fonts, saved to `test/ui/layout/shots/`, not in git):

```bash
flutter test test/ui/layout --dart-define=MFF_SHOTS=true --update-goldens
```

---

## Part C. Build a Release and Install It on a Phone

A release build needs the backend URL and the Google client ID, and the signing key's SHA-1 must be registered in Google Cloud, so the complete go-live steps live in the "Setup Guide" of the meta repo [`mama-fufood`](https://github.com/beethoreven/mama-fufood) README — follow that order.

To try a release build on your own emulator only (not on anyone else's phone), no real key is needed:

```bash
MFF_ALLOW_DEBUG_SIGNING=1 flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**Don't install a build signed this way on a phone that will be used long-term**: later builds signed with the real key won't install over it, and the only fix is uninstalling (which deletes the data).

---

## Part D. Settings Overview

**`env/prod.json`** (not in git; format in `env/prod.example.json`; passed at build time with `--dart-define-from-file=env/prod.json`; not secret):

| Field | Required? | Description |
|---|---|---|
| `MFF_API_BASE` | **Required** (for online features) | The backend URL, e.g. `https://mama-fufood-backend.onrender.com`, **no trailing slash**. Without it, update checks and feedback show "這個版本還沒設定後端網址" (this build has no backend URL configured). |
| `MFF_WEB_CLIENT_ID` | **Required** (for Google sign-in) | The Google Cloud "Web application" client ID (the same one as the backend's `GOOGLE_CLIENT_ID`). The Android client's ID isn't entered anywhere — Google matches it by package name plus SHA-1. |

**`android/key.properties`** (not in git; the release signing key):

| Field | Description |
|---|---|
| `storePassword` | The keystore password |
| `keyPassword` | The key password (usually the same as above when created with `keytool`) |
| `keyAlias` | The key alias, e.g. `upload` |
| `storeFile` | The **full path** to the keystore file, e.g. `/Users/<your account>/Keys/mama-fufood/upload-keystore.jks` |

**Environment variables:**

| Variable | Description |
|---|---|
| `MFF_ALLOW_DEBUG_SIGNING` | When set to `1`, a release build works without `key.properties` (signed with the debug key — for your own emulator only). |
