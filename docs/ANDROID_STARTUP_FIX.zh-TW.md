# Android 16 啟動閃退修正

2026-11-02，版本 1.9.1（Build 15）。

在 Android 16 / API 36.1 模擬器安裝實際發出的 1.9.0 Release APK，啟動前即發生 AndroidRuntime FATAL EXCEPTION。AndroidX Startup 初始化 WorkManager 時，拋出 `Failed to create an instance of androidx.work.impl.WorkDatabase`。當時尚未執行 Flutter 遊戲畫面。

原版 R8 usage 報告明確列出 `androidx.work.impl.WorkDatabase_Impl` 的 `public void <init>()` 被刪除。依賴中的 Room runtime 為 2.2.5，該生成資料庫依靠反射建立，壓縮後缺少無參數建構子而啟動失敗。

修正：android/app/proguard-rules.pro 保留 WorkDatabase_Impl 類別與無參數建構子，並由 android/app/build.gradle.kts 的 release 設定載入。保留既有 R8 壓縮、簽章、遊戲存檔與教學功能。

驗證：同一 Android 16 模擬器直接覆蓋安裝修正版 Release APK，連續三次停止後重新啟動，每次進程均持續運作，並以截圖確認出現遊戲開始畫面。APK 簽章驗證通過。此驗證不代表已在使用者的實體手機測試，也不代表完整實機語音／遊玩驗收。

本機證據位於 output/review/startup-crash/build14-crash.txt、build15-start.png 及 build/verification/android-startup.json。這些執行產物不提交 Git。

之後更動原生依賴或壓縮設定，請對最終 Release APK 執行啟動測試；僅執行 Dart/widget 測試無法覆蓋 AndroidX Startup 與 R8 行為：

```powershell
python tool/check_android_release_startup.py --adb "C:/Users/user/AppData/Local/Android/Sdk/platform-tools/adb.exe" --serial YOUR_QA_DEVICE --apk build/app/outputs/flutter-apk/app-release.apk
```

此腳本使用 install -r，保留資料，不會解除安裝或清除遊戲進度。會停止並重開指定測試裝置上的森星小隊三次。

交付：Builds/Android/forest-star-1.9.1-startup-fix-testads.apk（位於 Flutter 專案上兩層目錄）。SHA-256：AFE8E7CF9C7D8D1BC61714D05EA22D8D8B4359D3727522B20D2AAE844BEE14FB。

廣告仍為 Google 測試廣告。iOS 未因本次 Android 修正重新建置或上傳。
