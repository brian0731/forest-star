# 遊戲教學及中／英／粵語朗讀

更新：2026-11-02。

開始畫面的「新手教學 · 中 / English / 粵」及遊戲左上角的學士帽圖示均可進入。完成後，開始畫面會顯示「重溫遊戲教學」。教學由使用者主動開啟，可隨時關閉或返回。

十步包含營地地點、實際射球、六個籃子及夥伴成長、夥伴能力、星糖升級、星露進化、第四路配置、開始守衛、戰況與免費補給。可點亮起位置，或點「試試看・下一步」，執行練習操作。彈珠落定及升級／進化動畫播放完成後才進下一步。

練習有獨立 GameState、免費練習資源及關閉存檔的 GameSession；不消耗正式彈珠或改寫正式角色進度。真實遊戲在教學期間暫停，退出後恢復。練習沒有廣告，也沒有背景音樂，方便聽清楚旁白。

## 插件及語音行為

- `tutorial_coach_mark` 1.3.4：聚焦遊戲畫布座標，跟隨 SceneLayout 的縮放及安全區。
- `flutter_tts` 4.2.5：使用裝置語音；未接入 Google Cloud，沒有額外 API Key 或雲端帳單。
- 中文：優先 zh-TW，亦可選可用的中文普通話語音；英文：優先 en-US；粵語：yue-HK / zh-HK。沒有粵語時顯示缺少語音提示，不自動改讀普通話。
- Android 偵測已安裝的 `com.google.android.tts`，有則優先選用；未安裝時使用預設引擎。語音清單提供離線標記時，優先選擇可用的離線聲音。某些裝置未安裝 Google 服務。
- iPhone 使用 Apple AVSpeechSynthesizer 系統聲音，不能透過此插件指定 Google 聲音。
- 語言按鈕、朗讀開關及「再聽一次」皆在教學卡片內。選擇保存在本機。切換語言、退出教學、切換至背景都會停止上一段朗讀。
- 是否需要網路取決於裝置引擎及已下載的語音資料；不能保證所有裝置均內建三種語音。文字教學不依賴語音可用性。

## 你可在裝置完成的設定

Android：設定中搜尋「文字轉語音」／「文字轉語音輸出」，選 Google 語音引擎，進入語音資料設定，安裝中文、English、中文（香港）／粵語。選項名稱依 Android 品牌及版本不同。回遊戲按「再聽一次」。

iPhone：設定中搜尋「朗讀內容」或「語音」，在聲音清單下載中文、英文、中文（香港）／粵語聲音；實際路徑依 iOS 版本不同。回遊戲按「再聽一次」。

請實機確認三種語言發音、靜音／重播、回主畫面後停止朗讀、返回後遊戲音樂恢復，以及正式存檔沒有變更。自動測試及 APK 編譯無法代替真人聽音驗收。

## 建置與驗證

Android Manifest 已加入 TTS_SERVICE 查詢及 Google 語音套件可見性，不要求麥克風權限。iOS flutter_tts 目前僅提供 CocoaPods，專案透過 ios/Podfile 與現有 SwiftPM 並存。macOS 首次建置需安裝 CocoaPods；Flutter 會進行 pod install，產生 Podfile.lock 後應提交鎖檔。本次 Windows 環境不能執行 Xcode／iOS 原生編譯。

執行 `flutter test test/tutorial_test.dart` 驗證完整教學、資料隔離、語言切換、語音選擇與返回行為；執行 `flutter test` 回歸既有遊戲。設定 `FOREST_TUTORIAL_CAPTURE=1` 後執行教學測試，可在 output/review/tutorial 取得實際 Flutter 渲染截圖。

上架前須將此變更編成新 Build，先前已上傳的 iOS Build 13 不包含教學。App Review 外部服務說明可增加：

> Optional tutorial narration uses the device's text-to-speech service: an installed Google speech engine is preferred on Android, while iOS uses Apple's system speech synthesis. No Google Cloud Text-to-Speech API is integrated. Speech availability and network use depend on the installed device voices. The tutorial also works without narration and does not modify the player's saved progress.

參考：[教學插件](https://pub.dev/packages/tutorial_coach_mark)、[語音插件](https://pub.dev/packages/flutter_tts)。
