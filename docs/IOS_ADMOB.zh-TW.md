# iOS 正式獎勵廣告

2026-11-03，版本 1.9.1（Build 19）起，GitHub Actions 的 iOS 建置接入使用者提供的 AdMob 單元。

- 應用程式 ID：`ca-app-pub-7872649564668474~3617467257`
- 獎勵廣告單元 ID：`ca-app-pub-7872649564668474/6817511518`
- 設定檔：`config/admob.ios.production.json`。這些是公開應用程式／廣告單元識別碼，不是 API 密鑰。

營地點「廣告 +12」，確認後才播放。只有 Google 的 earned-reward 回呼可發放十二顆彈珠，每次廣告只發一次並存檔；取消、播放失敗或未達獎勵條件不發獎。免費補給保留，教學不播放廣告。

沿用已選擇的兒童適用處理、G 級、非個人化廣告；不新增 ATT 追蹤授權。啟動時透過 UMP 更新隱私狀態，`canRequestAds()` 允許後才初始化及載入正式廣告。若需要修改隱私選擇，可從遊戲隱私頁面開啟。

## 建置

Actions 先執行 `python3 tool/prepare_ios_admob.py`，把同一份 JSON 的 App ID 寫入 iOS Info.plist，再將 JSON 以 `--dart-define-from-file` 傳給 Flutter。封裝後再核對 Runner.app 的 App ID，避免原生測試 App ID 與正式 Dart 廣告單元混用。簽章、打包及上傳方式沿用既有 workflow。

本機 `flutter run` 預設仍使用官方測試廣告；勿將此 iOS JSON 用於 Android。開發驗收應使用官方測試 ID 或 AdMob 已登記的測試裝置，不要自行點擊正式廣告。

## AdMob／商店端工作

請在 AdMob 核對此 iOS App 的商店連結、應用程式就緒／驗證狀態，以及適用地區的「隱私權與訊息」設定。新廣告單元及帳戶審查可能需要時間，無填補時遊戲可重試並繼續免費遊玩；成功接入不代表已產生曝光或收益。

App Store Connect 的 App Privacy 須按 Google Mobile Ads SDK 的實際資料處理方式填寫，公開隱私政策也需更新。本機 `../../Builds/GooglePlay/privacy-policy.html` 及 App 內政策已更新為包含正式 iOS 廣告；公開政策網站的更新需要另行部署。

參考：[Flutter 獎勵廣告](https://developers.google.com/admob/flutter/rewarded)、[原生 App ID](https://developers.google.com/admob/flutter/quick-start)、[UMP 隱私流程](https://developers.google.com/admob/flutter/privacy)、[兒童及內容分級設定](https://developers.google.com/admob/flutter/targeting)。
