# 森星小隊：Flutter iOS · GitHub Actions 上架設定教學

更新日期：2026-11-03。適用倉庫：[brian0731/forest-star](https://github.com/brian0731/forest-star)。

Build 19 起，實際 workflow 使用正式 iOS AdMob 設定，並同時注入原生 Info.plist 及 Dart 編譯參數；詳細識別碼、驗收及帳戶設定見 [iOS AdMob 接入](IOS_ADMOB.zh-TW.md)。下方早期測試版紀錄及範本不代表目前正式廣告設定。

目標流程：準備 iOS 工程與 Apple 簽章 → GitHub Actions 建置 IPA → 上傳 App Store Connect → TestFlight 測試 → 提交 App Store 審核。

本文件提供已加入倉庫的 iOS 工程、設定步驟與完整 workflow。建置及上傳結果以 GitHub Actions 和 App Store Connect 為準。上傳 TestFlight 後，仍須完成商店資料、選擇 build 與送審，才會公開上架。

### 2026-10-30 實際上傳紀錄

- 版本：`1.8.0 (13)`；Bundle ID：`com.foreststar.foreststar`。
- [GitHub Actions 執行紀錄](https://github.com/brian0731/forest-star/actions/runs/41009891377)，建置來源 commit：`56b6042`。
- 雲端分析與遊戲測試、profile 驗證、Apple Distribution 匯入、IPA archive / export 與簽章驗證均成功。
- Apple 驗證成功，並回覆 `UPLOAD SUCCEEDED with no errors`；此為成功送達 App Store Connect，尚未確認 Apple 背景處理、測試群組開放或公開審核結果。
- IPA SHA-256：`6340cc339a4b7e0dd2c8284ec0ecf40e8ee74263fdae39e2a24e3797719cf2bc`。
- 此次 GitHub Artifact 備份受帳戶儲存額度限制，沒有可下載附件；未影響 Apple 上傳。
- 下一步：App Store Connect → 本 App → TestFlight，等待處理完成、回答實際加密合規問題，再選擇 build 加入測試群組。後續重新上傳使用大於 `13` 的 build number。

## 1. 這個專案目前的情況

- Flutter 專案已在倉庫根目錄，包含 `pubspec.yaml`、`lib/`、`assets/`、`android/`。
- 本機專案位置：`C:\Users\user\Desktop\forest-star\Flutter\forest_star`。
- 目前版本是 `1.8.0+12`，使用 Flutter 3.44.0 / Dart 3.12 與 Flame。
- 已加入 `ios/` 工程、正式圖示、啟動畫面及 `.github/workflows/ios-testflight.yml`。
- iOS Bundle ID 已依你提供的設定採用 `com.foreststar.foreststar`；請在 Apple Developer 與 App Store Connect 使用此 ID。本文件尚未替你操作 Apple 帳戶。
- Android 套件名稱仍為 `com.foreststar.forest_star`。
- Android / iOS 已分別使用各平台的官方測試廣告 ID。正式廣告收益需另行設定，見第 4 節。
- Android 的 `.jks`、`android/key.properties` 不能用來簽署 iOS。

以下命令都從 **Flutter 倉庫根目錄** 執行，不要再切到外層 `forest-star` 的舊 Git 倉庫。

## 2. 先準備帳戶及工具

### Apple

1. 準備可用的 [Apple Developer Program](https://developer.apple.com/programs/) 會員資格。
2. 確認可以進入 [Apple Developer 帳戶](https://developer.apple.com/account/) 和 [App Store Connect](https://appstoreconnect.apple.com/)。
3. 完成帳戶上待處理的合約；依實際營運方式完成所需的稅務、收款等資料。
4. 記下 Apple **Team ID**，以及正式決定的 **Bundle ID**。

### Windows 與 GitHub macOS runner

只有 Windows 也能準備簽章：用 OpenSSL 產生私鑰與 CSR，在 Apple 網站申請憑證及 profile，再於 Windows 製作 `.p12`。詳細命令見第 **5.1.1 節**。你不需要為了製作 `.p12` 購買或借用 Mac；正式編譯與簽署交給 GitHub Actions 的 macOS runner，完成後用 iPhone / TestFlight 驗收。

下文 Xcode 圖形介面步驟是有 Mac 時的設定方法。只有 Windows 時，須在編輯器配置 iOS 工程，並由 Actions 驗證；Windows 本身不能執行 Xcode 或 `flutter build ipa`。倉庫已加入 iOS 工程，CI 會根據你的 profile 自動配置 Runner 簽章。

本範本固定 `macos-15` 並明確選擇 `Xcode_26.3.app`；不要依賴 runner 的預設 Xcode。截至文件更新日，Apple 上傳最低要求為 Xcode 26 與 iOS 26 SDK。這是**編譯 SDK** 要求，並不代表只支援 iOS 26 手機。[Apple 要求](https://developer.apple.com/news/upcoming-requirements/) · [runner 軟體清單](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md)

## 3. 第一次建立 iOS 工程

### 3.1 下載倉庫並建立 iOS 工程

```bash
git clone https://github.com/brian0731/forest-star.git
cd forest-star
flutter --version
flutter pub get
flutter create --platforms=ios --org com.foreststar --project-name forest_star .
git diff
```

只在尚無 iOS 工程時執行 `flutter create`。檢查變更，保留既有遊戲程式、素材與 Android 設定；不要使用 `--overwrite`。

上述 Git / Flutter 命令也可以在 Windows PowerShell 執行。你已有本機倉庫時，直接切到 `C:\Users\user\Desktop\forest-star\Flutter\forest_star`，略過 clone；iOS 編譯留待 Actions 執行。

專案名稱 `forest_star` 可能讓產生的 Bundle ID 包含底線；建立後務必依下一節將 Runner 的 Debug / Profile / Release 都設為 `com.foreststar.foreststar`。若有 RunnerTests target，使用 `com.foreststar.foreststar.RunnerTests`，避免保留舊前綴。

Flutter 3.44 預設使用 Swift Package Manager；先保留預設，有外掛需要時 Flutter 會回退使用 CocoaPods。不要為了照抄舊教學自行刪除 SwiftPM 設定。若產生 `ios/Podfile.lock`，把它提交到 Git，讓 CI 使用同一份相依版本。[Flutter 套件管理說明](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)

### 3.2 設定 Xcode

先按照第 4 節加入 iOS AdMob 的原生設定，再執行：

```bash
flutter build ios --simulator --debug
open ios/Runner.xcworkspace
```

在 Xcode 選擇 **Runner project → Runner target**：

1. **General → Display Name**：`森星小隊`。
2. **Bundle Identifier**：填入 `com.foreststar.foreststar`；Runner 的所有 configuration、Apple 註冊與簽章 profile 必須完全相同。
3. **Minimum Deployments**：本教學採 iOS `15.0`。Runner 的 Debug / Profile / Release 與 `ios/Flutter/AppFrameworkInfo.plist` 的 `MinimumOSVersion` 保持一致；若外掛要求更高版本，以外掛要求為準。
4. **Supported Destinations / Devices**：先決定只支援 iPhone，或同時支援 iPad。若支援 iPad，須一併驗收版面、方向與補齊截圖。
5. **App Icons**：設定 `ios/Runner/Assets.xcassets/AppIcon.appiconset`，使用正式圖示。App Store 圖示提供 1024 × 1024、無透明通道的圖片，並依 Xcode 資產目錄的要求填齊。
6. **LaunchScreen.storyboard**：製作不變形的啟動畫面，與遊戲開始畫面配色一致。Flutter 內的開始畫面不會自動變成原生 Launch Screen。

若使用 CocoaPods，將 `ios/Podfile` 的平台設為 `platform :ios, '15.0'`。不要建立第二個 `post_install`；若日後升級 Xcode 要求提高 Pods 部署版本，將調整合併到既有 hook，保留 `flutter_additional_ios_build_settings(target)`。[Google 的部署版本說明](https://developers.google.com/admob/ios/quick-start)

### 3.3 註冊 App

1. Apple Developer → **Certificates, Identifiers & Profiles → Identifiers → + → App IDs → App**。
2. 建立明確的 Bundle ID：`com.foreststar.foreststar`，不要使用萬用字元。若你已建立此 ID，直接選用既有項目。
3. App Store Connect → **My Apps → + → New App**。
4. 平台選 iOS；填入名稱、主要語言、剛註冊的 Bundle ID，與自訂 SKU，例如 `forest-star-ios`。
5. SKU 是你的管理識別碼；不等於 Bundle ID，也不等於廣告 ID。

## 4. 本專案的 iOS 廣告與隱私設定

### 4.1 先配置 Info.plist

專案已啟用 iOS 測試廣告，並在 `ios/Runner/Info.plist` 的主 `<dict>` 中加入：

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>
```

以上是 **Google iOS 官方測試 App ID**，適合第一輪測試；正式廣告要換成自己在 AdMob 建立的 **iOS App ID**。參照 [Flutter 廣告設定](https://developers.google.com/admob/flutter/quick-start) 和 [iOS 原生設定](https://developers.google.com/admob/ios/quick-start)，加入當時要求的 `SKAdNetworkItems`。請取用官方最新清單。

**`--dart-define=ADMOB_APP_ID=...` 不會自動改寫 iOS Info.plist。** Android 現有的 Gradle 注入設定不能直接套用到 iOS。

### 4.2 本機測試及早期 Build 的 iOS 獎勵廣告設定

`lib/main.dart` 已支援 Android / iOS；`lib/rewarded_ads.dart` 會選擇對應平台的測試 rewarded ID。iOS 使用：

```text
AdMob App ID:       ca-app-pub-3940256099942544~1458002511
Rewarded unit ID:   ca-app-pub-3940256099942544/1712485313
```

原始 Info.plist 保留 iOS 測試 App ID 及 SKAdNetwork 清單，方便本機預設測試。Build 19 起，Actions 會在編譯前以 `tool/prepare_ios_admob.py` 寫入正式 App ID，並以 `config/admob.ios.production.json` 編譯 Dart 正式廣告設定。早期 TestFlight 的測試廣告沒有收益。資料來源：[Google 測試廣告](https://developers.google.com/admob/flutter/test-ads)。

使用者已提供 iOS AdMob App / rewarded 單元；請完成 AdMob 帳戶端設定及商店隱私申報後驗收。不可把 Android 的廣告 ID 填入 iOS。

### 4.3 上架前的兒童與隱私設定

本專案先前選擇兒童適用、非個人化廣告。延續此設定，並依 iOS 實際整合完成：

- 公開可瀏覽的 HTTPS 隱私政策 URL、遊戲內政策，以及聯絡方式 `info@foodbuyer.com.hk`。
- 更新 `assets/privacy-policy.txt`，說明 iOS 版、廣告 SDK 與實際資料用途；不能只沿用 Android 權限描述。
- App Store Connect 的 **App Privacy** 依實際 SDK 資料行為申報；遊戲本身只有本機存檔，不代表廣告 SDK 完全不處理資料。
- 驗證 SDK 隱私清單、所需 API 原因，以及正式模式的 UMP 訊息和隱私選擇入口。
- ATT 依是否進行 Apple 定義的追蹤決定；不要為了「有廣告」就直接加入要求追蹤的提示，也不要把「非個人化」直接等同於所有 SDK 都無追蹤。若需要，須實作權限流程與使用說明。
- 若選 Apple **Kids Category**，另外核對家長閘門、外連與第三方廣告限制；AdMob 的兒童旗標本身不能保證通過 Kids Category 審核。[Apple 兒童類別規則](https://developer.apple.com/app-store/review/guidelines/#kids-category)

## 5. 建立 iOS 正式簽章

這份範本採手動簽章，不會透過 API 自動建立、撤銷或更新憑證。

### 5.1 Apple Distribution 憑證與 .p12

這一步產生 `IOS_CERTIFICATE_P12_BASE64` 的來源檔案，以及 `IOS_CERTIFICATE_PASSWORD`。本節示範 Mac 鑰匙圈方式。

**A. 建立 CSR（憑證簽署要求）**

1. 在 Mac 用 Spotlight 搜尋並開啟 **Keychain Access／鑰匙圈存取**。
2. 上方選單選 **Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority**。
3. User Email Address 填自己的開發者電郵；Common Name 可填 `Forest Star Distribution`；CA Email Address 留空。
4. 選 **Saved to disk**，儲存 `.certSigningRequest`。

建立 CSR 時，對應的私鑰會留在這台 Mac 的鑰匙圈。後續下載的憑證要匯入同一台 Mac，才能配對。[Apple CSR 操作說明](https://developer.apple.com/help/account/certificates/create-a-certificate-signing-request/)

**B. 向 Apple 取得發佈憑證**

1. 登入 [Apple Developer → Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list)。
2. 選 **Certificates → + → Apple Distribution → Continue**。
3. 上傳剛才的 `.certSigningRequest`，完成建立並下載 `.cer`。
4. 在剛才建立 CSR 的 Mac 雙擊 `.cer`，匯入鑰匙圈。

需要有建立發佈憑證的帳戶權限；若沒有相應選項，請帳戶管理員協助。已有可用且有私鑰的 Apple Distribution 憑證時，可直接匯出，不需撤銷既有憑證。

**C. 匯出含私鑰的 .p12，設定密碼**

1. 鑰匙圈選 **login／登入 → My Certificates／我的憑證**。
2. 找到 `Apple Distribution: …`，展開左側箭頭，應能看到對應私鑰。
3. 選取這張憑證，右鍵 **Export／輸出**，格式選 **Personal Information Exchange (.p12)**。
4. 儲存為 `ForestStar-Distribution.p12`。
5. 匯出視窗要求密碼時，設定一組自己的強密碼並保存。**這組密碼原文就是 `IOS_CERTIFICATE_PASSWORD`**，不需要 Base64。
6. 如果 Mac 接著要求鑰匙圈／登入密碼，那只是授權匯出；不要把 Mac 登入密碼誤填為 GitHub 的憑證密碼。

若看不到私鑰、無法選 `.p12`，表示憑證沒有與私鑰配對。請回到建立 CSR 的 Mac 匯出，或從可信備份還原；只有 `.cer` 或 `AuthKey_*.p8` 不能代替這張憑證的私鑰。

忘記 `.p12` 匯出密碼時，不能從 GitHub Secret 讀回明文；如果鑰匙圈仍有憑證與私鑰，可重新匯出並設定新密碼，再同時更新兩個憑證 Secrets。

最後依第 7 節將 `.p12` 編碼為 Base64，填入 `IOS_CERTIFICATE_P12_BASE64`。安全備份原始檔與匯出密碼。

### 5.1.1 只有 Windows：用 OpenSSL 製作 .p12

**此路徑可以取代第 5.1 節的 Mac 鑰匙圈操作。** 已確認這台 Windows 有 `C:\Program Files\Git\usr\bin\openssl.exe`。以下命令使用 Windows PowerShell，請逐段執行。

**A. 選擇私人資料夾與工具**

```powershell
$iosOpenSSL = 'C:\Program Files\Git\usr\bin\openssl.exe'
$iosSigningDir = 'C:\Users\user\Desktop\IOS Key'
New-Item -ItemType Directory -Path $iosSigningDir -Force | Out-Null
Set-Location -LiteralPath $iosSigningDir
& $iosOpenSSL version
```

此資料夾在 Git 倉庫之外，保留你原有的 `AuthKey_ZXU4DD9BVU.p8`。下面會產生另一把發佈簽章私鑰；不要使用該 `.p8` 代替。

**B. 產生加密私鑰與 CSR**

```powershell
if ((Test-Path 'ForestStar-Distribution.key') -or
    (Test-Path 'ForestStar-Distribution.certSigningRequest')) {
    throw '簽章私鑰或 CSR 已存在，請沿用原檔，不要覆寫。'
}
& $iosOpenSSL req -new -newkey rsa:2048 -sha256 `
    -keyout 'ForestStar-Distribution.key' `
    -out 'ForestStar-Distribution.certSigningRequest' `
    -subj '/CN=Forest Star Distribution/emailAddress=info@foodbuyer.com.hk'
if ($LASTEXITCODE -ne 0) { throw '產生 CSR 失敗，請先處理 OpenSSL 錯誤。' }
& $iosOpenSSL req -in 'ForestStar-Distribution.certSigningRequest' -verify -noout
```

出現 `Enter PEM pass phrase` 時，設定並再次輸入**私鑰保護密碼**。輸入時不顯示文字是正常的。電郵可先換成自己的 Apple 開發者聯絡電郵。

- `.key`：加密的簽章私鑰，留在自己電腦，安全備份。
- `.certSigningRequest`：CSR，下一步只上傳這個檔案給 Apple。
- 若前一步失敗留下部分檔案，先確認錯誤與檔案狀態，不要直接重新產生並覆蓋已用於申請憑證的私鑰。

**C. Apple 網站簽發 .cer**

1. 開啟 [Apple Developer → Certificates](https://developer.apple.com/account/resources/certificates/list)。
2. 選 **+ → Apple Distribution → Continue**。
3. 上傳 `ForestStar-Distribution.certSigningRequest`。
4. 下載 Apple 簽發的 `.cer`，存到 `C:\Users\user\Desktop\IOS Key`，重新命名為 `distribution.cer`。

不用在 Windows 雙擊安裝憑證；直接進下一步轉檔即可。必須有 Apple Developer 會員與建立此憑證的帳戶權限。

**D. 把 Apple 憑證與自己的私鑰封裝成 .p12**

回到剛才的 PowerShell，在相同資料夾執行：

```powershell
& $iosOpenSSL x509 -inform DER -in 'distribution.cer' `
    -out 'ForestStar-Distribution.pem'
if ($LASTEXITCODE -ne 0) { throw '憑證轉檔失敗，請確認下載的是 Apple .cer。' }
if (Test-Path 'ForestStar-Distribution.p12') {
    throw '.p12 已存在，請先確認是否需要更新，避免覆寫備份。'
}
& $iosOpenSSL pkcs12 -export `
    -inkey 'ForestStar-Distribution.key' `
    -in 'ForestStar-Distribution.pem' `
    -name 'Forest Star Apple Distribution' `
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 `
    -out 'ForestStar-Distribution.p12'
if ($LASTEXITCODE -ne 0) { throw '.p12 建立失敗，請先處理憑證／私鑰錯誤。' }
```

封裝採相容 Apple keychain 的 PKCS#12 演算法。命令會依序詢問：

1. `Enter pass phrase for ...key`：輸入 B 步驟的**私鑰保護密碼**。
2. `Enter Export Password`：設定 `.p12` 的**匯出密碼**。
3. `Verifying - Enter Export Password`：再輸入一次匯出密碼。

**第 2 項匯出密碼原文才是 `IOS_CERTIFICATE_PASSWORD`**；私鑰保護密碼只留在本機。如果出現 `No cert ... matches private key`，表示 `.cer` 不是用這份 CSR 申請的，須重新核對配對。

可用以下命令檢查封裝；輸入 `.p12` 匯出密碼，`-noout` 不會輸出私鑰：

```powershell
& $iosOpenSSL pkcs12 -in 'ForestStar-Distribution.p12' -info -noout
```

**E. 填入憑證 Secrets**

```powershell
Set-Clipboard -Value ([Convert]::ToBase64String([IO.File]::ReadAllBytes(
    'C:\Users\user\Desktop\IOS Key\ForestStar-Distribution.p12')))
```

將剪貼簿貼入 GitHub 的 `IOS_CERTIFICATE_P12_BASE64`；另把 D 步驟的匯出密碼填入 `IOS_CERTIFICATE_PASSWORD`。繼續第 5.2 節，在網頁建立 `.mobileprovision`，整個準備簽章過程可留在 Windows 完成。

以上使用標準 OpenSSL [CSR 命令](https://docs.openssl.org/3.5/man1/openssl-req/) 與 [PKCS#12 封裝命令](https://docs.openssl.org/3.5/man1/openssl-pkcs12/)。真正的發佈憑證必須由 Apple 簽發，不可自行簽一張測試憑證當作 Apple Distribution。

### 5.2 App Store Connect provisioning profile

Apple Developer → **Profiles → + → Distribution → App Store Connect**：

1. 登入 [Apple Developer → Profiles](https://developer.apple.com/account/resources/profiles/list)，按 **+**。
2. 在 Distribution 選 **App Store Connect**，按 Continue。
3. 選本 App 的明確 Bundle ID：`com.foreststar.foreststar`。若找不到，先到 Identifiers 註冊，並確認登入的 Team 正確。
4. 選第 5.1 節匯出 `.p12` 所對應的 **同一張 Apple Distribution 憑證**。
5. Profile Name 填 `ForestStar-AppStore`，按 Generate。
6. 按 Download，取得 `.mobileprovision`。下載檔名可能與顯示名稱不同；可統一命名為 `ForestStar-AppStore.mobileprovision`。
7. 使用 Windows 時直接保留下載檔供編碼與 CI 安裝；使用 Mac 本機建置時，再安裝此 profile。
8. 依第 7 節編碼**整個檔案**，結果填入 `IOS_PROFILE_BASE64`，不要填 profile 名稱、UUID 或網頁網址。

不要選 Development 或 Ad Hoc profile。操作依據：[Apple provisioning profile 說明](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/)。

### 5.3 CI 自動配置 Runner 簽章

本倉庫已提供 `tool/prepare_ios_signing.py`。Actions 解碼 profile 後，會驗證 Team ID、Bundle ID、到期時間及 App Store 發佈類型，再自動設定 Runner Release / Profile 的手動簽章與 IPA export options。只有 Windows 也不需先開 Xcode。

請先填好第 7 節的 Secrets 及 Variables，然後執行 Actions。實際 archive、憑證與私鑰配對、簽章與匯出驗證由 macOS runner 完成。若新增其他 target 或 flavor，需相應擴充工具與 profiles。

## 6. 建立 App Store Connect 上傳 API Key

由 Account Holder / Admin 進入 **App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys**：

1. 建立名稱，例如 `GitHub Forest Star Upload`。
2. 只上傳 build 的流程可使用具有上傳權限的 **Developer** 角色；如有額外 App 管理需求，再評估 App Manager。
3. 記下 **Key ID** 和 **Issuer ID**。
4. 下載 `AuthKey_你的KeyID.p8`，安全保存。私鑰只能下載一次。

這份範本使用 **Team API Key + Issuer ID**，不要與個人 API key 或 APNs 推播金鑰混用。Team API key 的作用範圍也須由帳戶管理者確認。[Apple API key 設定](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/)

## 7. 設定 GitHub Secrets 與 Variables

打開倉庫 **Settings → Secrets and variables → Actions**。

### Repository secrets

- `IOS_CERTIFICATE_P12_BASE64`：`.p12` 檔案內容的 Base64。
- `IOS_CERTIFICATE_PASSWORD`：匯出 `.p12` 時設定的密碼。
- `IOS_PROFILE_BASE64`：`.mobileprovision` 檔案內容的 Base64。
- `IOS_KEYCHAIN_PASSWORD`：自行產生的隨機密碼，只用於 CI 暫存鑰匙圈。
- `ASC_API_KEY_P8_BASE64`：`AuthKey_*.p8` 檔案內容的 Base64；上傳 TestFlight 時需要。
- `ASC_KEY_ID`：App Store Connect Team API Key 的 Key ID。
- `ASC_ISSUER_ID`：該 Team API Key 的 Issuer ID。

### Repository variables

- `APPLE_TEAM_ID`：Apple Team ID。
- `IOS_BUNDLE_ID`：`com.foreststar.foreststar`。

以下 PowerShell 範例將檔案編碼後放到剪貼簿，再貼到相應 Secret。**在存放檔案的私人位置執行**，逐次修改檔名，貼上完成後清除剪貼簿。Base64 是編碼，不是加密。

```powershell
Set-Clipboard -Value ([Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\private\ForestStar-Distribution.p12')))
# 貼入 IOS_CERTIFICATE_P12_BASE64

Set-Clipboard -Value ([Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\private\ForestStar-AppStore.mobileprovision')))
# 貼入 IOS_PROFILE_BASE64

Set-Clipboard -Value ([Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\private\AuthKey_YOURKEYID.p8')))
# 貼入 ASC_API_KEY_P8_BASE64

Set-Clipboard -Value ''
```

Mac 可以用 `base64 -i 檔案路徑 | pbcopy`。不要把 `.p8`、`.p12`、profile、解碼後的內容或密碼放進 Git、README、workflow 明文或 Actions artifact。建議在 `.gitignore` 補上 `*.p8`、`*.mobileprovision`、`*.provisionprofile`；現有規則已排除 `*.p12`。

### 7.1 產生 IOS_KEYCHAIN_PASSWORD

這組密碼由你自行產生，供每次 Actions 建立暫存 keychain 使用。它不是 Apple ID 密碼、不是 Mac 登入密碼，也不必與 `.p12` 匯出密碼相同。[GitHub 官方說明](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)

在 Windows PowerShell 執行以下命令，產生 32 bytes 的密碼學隨機資料，轉成可貼上的文字並複製到剪貼簿。**此處的 Base64 只是隨機密碼的文字格式，不是另一個 Apple 檔案。**

```powershell
$iosKeychainBytes = New-Object byte[] 32
$iosKeychainRng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
    $iosKeychainRng.GetBytes($iosKeychainBytes)
    Set-Clipboard -Value ([Convert]::ToBase64String($iosKeychainBytes))
} finally {
    $iosKeychainRng.Dispose()
    [Array]::Clear($iosKeychainBytes, 0, $iosKeychainBytes.Length)
    Remove-Variable iosKeychainBytes, iosKeychainRng
}
```

執行後，在 GitHub 新增 `IOS_KEYCHAIN_PASSWORD`，Value 直接貼上。貼好再用 `Set-Clipboard -Value ''` 清除剪貼簿，不要在貼上前清掉。

### 7.2 逐一新增四個 Secrets

1. 倉庫 **Settings → Secrets and variables → Actions → Secrets → New repository secret**。
2. Name 填 `IOS_CERTIFICATE_P12_BASE64`，Secret 貼 `.p12` 編碼結果，按 Add secret。
3. 再新增 `IOS_CERTIFICATE_PASSWORD`，貼你匯出 `.p12` 時設定的**原文密碼**。
4. 再新增 `IOS_PROFILE_BASE64`，貼 `.mobileprovision` 的編碼結果。
5. 再新增 `IOS_KEYCHAIN_PASSWORD`，貼第 7.1 節產生的隨機密碼。

這四項都放在 **Secrets** 分頁；`IOS_BUNDLE_ID` 和 `APPLE_TEAM_ID` 則放 **Variables** 分頁。你現有的 `AuthKey_ZXU4DD9BVU.p8` 是 App Store Connect 上傳 API 私鑰，只用來準備 `ASC_API_KEY_P8_BASE64`，不能取代以上四項。

## 8. 新增 GitHub Actions workflow

建立 `.github/workflows/ios-testflight.yml`，內容如下。這個路徑位於倉庫根目錄，**不用再加 `Flutter/forest_star/` 前綴**。

範本只有手動執行入口；必須從 `main` 執行。第一次保留 `upload_testflight=false`，只產生可下載的 IPA。完成設定後，下一次使用更大的 build number，勾選上傳。

```yaml
name: iOS - Build and TestFlight

on:
  workflow_dispatch:
    inputs:
      build_number:
        description: 'New iOS build number (increase after every accepted upload)'
        required: true
        default: '13'
        type: string
      upload_testflight:
        description: 'Upload the signed IPA to App Store Connect / TestFlight'
        required: true
        default: false
        type: boolean

permissions:
  contents: read

concurrency:
  group: forest-star-ios-release
  cancel-in-progress: false

jobs:
  ios:
    if: github.ref == 'refs/heads/main'
    runs-on: macos-15
    timeout-minutes: 60
    defaults:
      run:
        shell: bash
    env:
      APPLE_TEAM_ID: ${{ vars.APPLE_TEAM_ID }}
      IOS_BUNDLE_ID: ${{ vars.IOS_BUNDLE_ID }}
      BUILD_NUMBER: ${{ inputs.build_number }}

    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
        with:
          persist-credentials: false

      - name: Validate configuration and select Xcode
        env:
          CERT_PASSWORD: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}
          KEYCHAIN_PASSWORD: ${{ secrets.IOS_KEYCHAIN_PASSWORD }}
        run: |
          set -euo pipefail
          test -f ios/Runner.xcodeproj/project.pbxproj
          test -n "$APPLE_TEAM_ID"
          test "$IOS_BUNDLE_ID" = 'com.foreststar.foreststar'
          [[ "$BUILD_NUMBER" =~ ^[1-9][0-9]{0,3}$ ]]
          if [[ -z "$CERT_PASSWORD" ]]; then
            echo '::error::Set IOS_CERTIFICATE_PASSWORD to the P12 export password.'
            exit 1
          fi
          test -n "$KEYCHAIN_PASSWORD"
          test -d /Applications/Xcode_26.3.app
          sudo xcode-select -s /Applications/Xcode_26.3.app/Contents/Developer
          xcodebuild -version
          xcrun --sdk iphoneos --show-sdk-version

      - name: Set up Flutter
        uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2
        with:
          flutter-version: '3.44.0'
          channel: stable
          cache: true

      - name: Dependencies and game checks
        run: |
          set -euo pipefail
          flutter pub get --enforce-lockfile
          flutter analyze --no-fatal-infos
          flutter test

      - name: Decode signing files
        env:
          CERT_BASE64: ${{ secrets.IOS_CERTIFICATE_P12_BASE64 }}
          PROFILE_BASE64: ${{ secrets.IOS_PROFILE_BASE64 }}
        run: |
          set -euo pipefail
          umask 077
          python3 - <<'PY'
          import base64, os
          from pathlib import Path
          for key, name in [('CERT_BASE64', 'ios-signing.p12'),
                            ('PROFILE_BASE64', 'ios-signing.mobileprovision')]:
              value = ''.join(os.environ.get(key, '').split())
              if not value:
                  raise SystemExit(f'Missing signing secret: {key}')
              (Path(os.environ['RUNNER_TEMP']) / name).write_bytes(
                  base64.b64decode(value, validate=True))
          PY
          security cms -D -i "$RUNNER_TEMP/ios-signing.mobileprovision" \
            > "$RUNNER_TEMP/ios-profile.plist"
          python3 tool/prepare_ios_signing.py \
            --profile-plist "$RUNNER_TEMP/ios-profile.plist" \
            --profile-file "$RUNNER_TEMP/ios-signing.mobileprovision" \
            --team "$APPLE_TEAM_ID" --bundle "$IOS_BUNDLE_ID" \
            --export-plist "$RUNNER_TEMP/ExportOptions.plist"

      - name: Import Apple Distribution identity
        env:
          P12_PASSWORD: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}
          KEYCHAIN_PASSWORD: ${{ secrets.IOS_KEYCHAIN_PASSWORD }}
        run: |
          set -euo pipefail
          signing_keychain="$RUNNER_TEMP/forest-star-signing.keychain-db"
          security create-keychain -p "$KEYCHAIN_PASSWORD" "$signing_keychain"
          security set-keychain-settings -lut 21600 "$signing_keychain"
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$signing_keychain"
          security import "$RUNNER_TEMP/ios-signing.p12" \
            -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$signing_keychain"
          security set-key-partition-list -S apple-tool:,apple:,codesign: \
            -s -k "$KEYCHAIN_PASSWORD" "$signing_keychain" >/dev/null
          security list-keychains -d user -s "$signing_keychain" \
            "$HOME/Library/Keychains/login.keychain-db"

      - name: Archive and export signed IPA
        run: |
          set -euo pipefail
          flutter build ipa --release \
            --build-number="$BUILD_NUMBER" \
            --export-options-plist="$RUNNER_TEMP/ExportOptions.plist"
          shopt -s nullglob
          ipas=(build/ios/ipa/*.ipa)
          [[ ${#ipas[@]} -eq 1 ]]
          codesign --verify --deep --strict \
            build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app
          shasum -a 256 "${ipas[0]}"

      - name: Save IPA and debug symbols
        # Optional backup: exhausted artifact quota must not block Apple upload.
        continue-on-error: true
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7
        with:
          name: forest-star-ios-${{ inputs.build_number }}
          path: |
            build/ios/ipa/*.ipa
            build/ios/archive/*.xcarchive/dSYMs/
          if-no-files-found: error
          retention-days: 7

      - name: Upload to App Store Connect
        if: inputs.upload_testflight
        env:
          ASC_KEY_BASE64: ${{ secrets.ASC_API_KEY_P8_BASE64 }}
          ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
        run: |
          set -euo pipefail
          umask 077
          python3 - <<'PY'
          import base64, os, re
          from pathlib import Path
          key_id = os.environ.get('ASC_KEY_ID', '')
          value = ''.join(os.environ.get('ASC_KEY_BASE64', '').split())
          if not re.fullmatch(r'[A-Za-z0-9]+', key_id):
              raise SystemExit('Missing or invalid ASC_KEY_ID')
          if not value or not os.environ.get('ASC_ISSUER_ID'):
              raise SystemExit('Missing App Store Connect API secrets')
          folder = Path.home() / '.appstoreconnect/private_keys'
          folder.mkdir(parents=True, exist_ok=True)
          (folder / f'AuthKey_{key_id}.p8').write_bytes(
              base64.b64decode(value, validate=True))
          PY
          ipas=(build/ios/ipa/*.ipa)
          xcrun altool --validate-app --type ios --file "${ipas[0]}" \
            --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
          xcrun altool --upload-app --type ios --file "${ipas[0]}" \
            --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
          echo 'Upload accepted. Check processing and testing status in App Store Connect.' \
            >> "$GITHUB_STEP_SUMMARY"

      - name: Clean up signing material
        if: always()
        run: |
          security delete-keychain "$RUNNER_TEMP/forest-star-signing.keychain-db" \
            >/dev/null 2>&1 || true
          python3 - <<'PY'
          import os, plistlib
          from pathlib import Path
          temp = Path(os.environ['RUNNER_TEMP'])
          profile_file = temp / 'ios-profile.plist'
          if profile_file.exists():
              try:
                  with profile_file.open('rb') as f:
                      uuid = plistlib.load(f)['UUID']
                  for folder in [Path.home() / 'Library/MobileDevice/Provisioning Profiles',
                                 Path.home() / 'Library/Developer/Xcode/UserData/Provisioning Profiles']:
                      (folder / f'{uuid}.mobileprovision').unlink(missing_ok=True)
              except (ValueError, KeyError, plistlib.InvalidFileException):
                  pass
          for name in ['ios-signing.p12', 'ios-signing.mobileprovision',
                       'ios-profile.plist', 'ExportOptions.plist']:
              (temp / name).unlink(missing_ok=True)
          folder = Path.home() / '.appstoreconnect/private_keys'
          if folder.exists():
              for key in folder.glob('AuthKey_*.p8'):
                  key.unlink()
          PY
```


本倉庫已有實際 workflow，不需重複建立。它使用 `tool/prepare_ios_signing.py` 驗證 profile，從 profile 取得 UUID，在 CI 自動將 Runner 的 Release / Profile 設為手動簽章，不需在 Windows 手動猜 profile 名稱。新倉庫複製範本時，也要複製該 Python 工具。

### 範本的使用範圍

- IPA / dSYM artifact 是額外備份。若 GitHub Artifact 額度已滿，備份失敗不會阻擋 Apple 上傳，但該次 run 可能沒有可下載的 IPA。請分別查看 Artifact 步驟及 Apple 上傳步驟，並自行管理帳戶的備份空間。

- 適用目前只有一個 Runner App、沒有 extensions、沒有 flavor 的專案。新增 Widget / Notification Service 等 target 後，每個 Bundle ID 都需自己的 profile 與 export mapping。
- 使用 GitHub-hosted runner；清理步驟以每次全新 runner 為前提，不適合直接套在多人共用的 self-hosted Mac。
- `--build-number` 使用手動輸入，避免 workflow 重建或重新執行時誤用已上傳的編號。範本接受 1–9999；需要其他版本格式時，再依 Apple 規則修改。
- `--build-name` 未覆寫，版本名稱來自 `pubspec.yaml`，目前為 `1.8.0`。未來可更新為 `1.8.1+14`；App Store Connect 的版本名稱要與 IPA 一致。
- profile、憑證、Xcode 路徑與 Actions 版本需要維護；範本不會自動續期。runner 清單若移除 Xcode 26.3，先選擇清單中可用、符合 Apple 要求的版本，再更新路徑。
- 官方 Actions 的範本參考：[checkout](https://github.com/actions/checkout)、[upload-artifact](https://github.com/actions/upload-artifact)；Flutter 安裝使用 [subosito/flutter-action](https://github.com/subosito/flutter-action)。投入正式使用時，可將 action tag 固定到審查過的完整 commit SHA。
- 簽章方法參考 [GitHub 官方教學](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)；IPA 建置參考 [Flutter iOS 發佈](https://docs.flutter.dev/deployment/ios)；上傳工具參考 [Apple upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)。

## 9. 提交設定並第一次執行

先用 `git status --short` 檢查，應提交 `ios/` 的工程、AppIcon、啟動畫面、相依鎖定檔、workflow 與必要程式修正；排除 `Pods/`、Flutter 產物及私人簽章檔。勿使用 `git add -f` 強行加入被忽略的檔案。

確認本次列出的目錄沒有混入私鑰後，可執行：

```bash
git add ios .metadata .github/workflows/ios-testflight.yml
# 若修改 Dart / pubspec / .gitignore，再逐一加入對應檔案。
git diff --cached --stat
git commit -m "Add iOS project and TestFlight workflow"
git push origin main
```

接著在 GitHub：

1. **Actions → iOS - Build and TestFlight → Run workflow**。
2. Branch 選 `main`。
3. Build number 填 `13`，前提是 Apple 尚未使用過此編號；否則填更大的數字。
4. 第一次不勾選 `upload_testflight`，先確認檢查、archive、IPA 匯出全部成功。
5. 在該次 run 的 **Artifacts** 下載 IPA 與 debug symbols 備份。App Store distribution IPA 不能像 APK 一樣直接側載到任意 iPhone。
6. 第二次填更大的 build number，例如 `14`，勾選 `upload_testflight`，執行上傳。

GitHub 私有倉庫使用 macOS runner 可能消耗額度或產生費用；依你的方案檢查 Actions 用量。不要把正式簽章工作流改成自動執行任意 fork PR 的程式碼。

## 10. TestFlight 測試與正式上架

### TestFlight

1. Actions 顯示上傳成功後，到 App Store Connect 選本 App → **TestFlight**，等待 Apple 處理 build。
2. 按實際功能完成 Export Compliance / 加密問題；不要一律填沒有加密。
3. 加入內部測試群組，選擇 build 並開放測試。在 iPhone 安裝 TestFlight 測試。
4. 外部測試需補齊測試資訊，並依 Apple 的流程完成 Beta App Review。

本遊戲驗收重點：開始畫面、營地全屏、彈珠台尺寸、六個夥伴籃、進化特效、四隊守衛、營地散步、音效、切背景暫停與回來恢復、Safe Area、存檔重開。若啟用廣告，再驗收 iOS 官方測試廣告、同意流程、取消不發獎、完成只發一次、廣告後音樂與操作恢復。

### App Store 正式版

1. **App Store → iOS App → 建立／選擇對應版本**。
2. 填寫名稱、副標題、描述、關鍵字、分類、分級問卷、版權、支援 URL、隱私政策 URL 與審查聯絡資料。
3. 上傳 App Store Connect 當下要求尺寸的 iPhone 截圖；支援 iPad 時補對應截圖。Google Play 的 1024 × 500 主題圖片不能直接代替 App Store 截圖。
4. 依實際 SDK 完成 App Privacy；確認 iOS 正式廣告、兒童設定與商店描述一致。
5. 選擇已完成處理與驗收的 build。若沒有帳號登入，在審查說明中說明不需登入；若有廣告入口，說明實際操作位置與獎勵方式。
6. 選手動或審核後自動發佈，再 **Add for Review / Submit for Review**。
7. 審核通過後，依選擇的發佈方式公開。

此 workflow 自動化到「上傳 App Store Connect」為止；正式送審與公開發佈在上面這些步驟完成。

## 11. 常見問題

### Actions 找不到 Run workflow

確認 `.github/workflows/ios-testflight.yml` 已提交到預設分支 `main`、副檔名是 `.yml`、YAML 沒有縮排錯誤，且倉庫 Actions 功能已開啟。

### 找不到 ios/Runner.xcodeproj

尚未提交 iOS 工程，或 workflow 放在錯誤的外層倉庫。先完成第 3 節；不要每次 CI 都臨時 `flutter create`，以免缺少已配置的圖示、簽章和隱私設定。

### No profiles / requires a development team / No signing certificate

核對第 5.3 節 Runner **Release** 設定；Team ID、Bundle ID、profile 名稱、profile 的憑證必須與 Secrets 中 `.p12` 一致。`.p12` 必須包含私鑰。`ExportOptions.plist` 不會自動替 archive 配置手動簽章。

### User interaction is not allowed / errSecInternalComponent

檢查 `.p12` 密碼、暫存 keychain 是否已解鎖、partition list 設定，以及 Apple Distribution 憑證是否有效且有私鑰。勿直接移除簽章步驟繞過。

### Profile expired / Bundle ID does not match

重新建立符合此 Bundle ID、Team、憑證與 capabilities 的 App Store profile，更新 `IOS_PROFILE_BASE64`；若名稱改變，也更新 Xcode 的 Release / Profile 設定。

### Flutter / Dart 版本或套件解析失敗

目前 `pubspec.yaml` 要求 Dart `^3.12.0`；不要套用只安裝舊版 Flutter 的範本。依實際採用的 Flutter 版本同步更新 workflow 與相依鎖定檔。

### CocoaPods / SwiftPM 解析失敗

先在相同 Flutter / Xcode 版本的 Mac 重現。保留 Flutter 3.44 的套件管理設定，檢查外掛是否支援目前的工具鏈；若使用 CocoaPods，核對 `Podfile` 和已提交的 `Podfile.lock`。不要在 CI 每次無條件刪除 lock 或執行全面升級。

### altool 認證失敗 / 401 / 找不到 API key

確認使用 **App Store Connect Team Key**；Issuer ID 與 Key ID 正確、角色可以上傳、key 未撤銷。`.p8` 內容不能貼成檔名或 Apple 推播金鑰。範本會寫入工具搜尋的 `~/.appstoreconnect/private_keys/AuthKey_KEYID.p8`。

### Duplicate build number

使用比 App Store Connect 上該版本已上傳編號更大的新 build number，再按 **Run workflow**。不要直接 Re-run jobs 重送已接受的同一份 IPA。

### Actions 上傳成功，TestFlight 還看不到

Apple 仍可能在處理。檢查 App Store Connect、通知信件，以及版本、Bundle ID 是否選錯；上傳成功不等於 Beta 審查或 App Store 審查已通過。

### 沒有廣告，或廣告沒有收入

Build 19 起 Actions 使用正式 iOS 單元，本機預設仍使用官方測試 ID。請依 [iOS AdMob 接入](IOS_ADMOB.zh-TW.md) 檢查帳戶、App／單元、隱私訊息、應用程式驗證與廣告填補狀態；測試廣告沒有收益。

## 12. 完成標準

- [ ] 已註冊 Apple Bundle ID，並建立 App Store Connect App。
- [ ] `ios/` 工程、圖示、啟動畫面與 Release 手動簽章已提交。
- [ ] Secrets 與 Variables 已填好，沒有私人檔案進 Git。
- [ ] Actions 建置出有正確版本與簽章的 IPA。
- [ ] TestFlight 處理完成，iPhone 實機驗收通過。
- [ ] 已決定 iOS 正式廣告策略，並完成相應程式、隱私與兒童設定。
- [ ] App Store 截圖、描述、分級、App Privacy、政策 URL 與審查資料齊備。
- [ ] 已在 App Store Connect 提交審核，通過後依設定發佈。
