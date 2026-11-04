# 森林告示板：更新伺服器 HTML

開始頁的告示板預覽與展開閱讀頁均使用官方 `webview_flutter`，直接載入伺服器網頁；Android 使用系統 WebView，iOS 使用 WKWebView。輕觸後可展開閱讀、捲動、重新整理及關閉：

`https://star.singtu.hk/notice.html`

這個功能需要下一次手動建置／安裝新版 App 才會出現。本次沒有輸出 APK 或執行 iOS Actions；下列伺服器檔案也尚未代為部署。

## Linux VPS／Nginx 首次設定

1. 修改專案內的 `server/updates/public/notice.html`。請以 UTF-8 儲存。
2. 用 WinSCP／SFTP 上傳到原先更新網站的根目錄。若沿用專案 Nginx 範例，實體路徑為：

   `/var/www/forest-star-updates/notice.html`

3. 在目前啟用的 HTTPS `server` 區塊內加入以下設定。請保留現有 HTTPS 憑證與其他路由。

   ```nginx
   location = /notice.html {
       try_files $uri =404;
       default_type text/html;
       charset utf-8;
       add_header Cache-Control "no-cache, max-age=0, must-revalidate" always;
       add_header X-Content-Type-Options nosniff always;
   }
   ```

4. 在 VPS 終端機檢查並重新載入：

   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   curl -i https://star.singtu.hk/notice.html
   ```

   確認回傳 `200`、`Content-Type: text/html`，且中文字正常。

5. 開啟新版 App，輕觸告示板，再按右上角重新整理。WebView 顯示載入進度；主頁面出現 HTTP／連線錯誤或 20 秒未完成時，顯示離線文字及重試按鈕。離線文字取自上次成功擷取的純文字格式公告，首次使用則為內建歡迎內容；遊戲仍可開始。網頁完整樣式不保證離線保留。

## 往後修改公告

直接替換同一份 `notice.html`，無須改動 `update-v1.json`、`contentVersion` 或 200MB 素材包。使用者下次啟動開始頁或按公告重新整理即可讀取新內容。已開啟的 App 不會在背景持續輪詢。

```html
<h2>森林週末活動</h2>
<p>歡迎回來！今天到彈珠屋陪夥伴練習吧。</p>
<ul>
  <li><strong>小提示：</strong>不同顏色彈珠的碰撞次數不同。</li>
  <li>收集成長分，看看夥伴進化的驚喜。</li>
</ul>
<blockquote>活動公告只提供資訊；活動規則與獎勵仍須在遊戲資料中設定。</blockquote>
```

## HTML 與 WebView

- 線上直接以 WebView 載入原始網址，保留 HTML、CSS、圖片及 JavaScript；不再把線上公告轉成 Flutter 文字版。
- 建議在 `<head>` 加入 `<meta name="viewport" content="width=device-width, initial-scale=1">`，並設定 `img { max-width: 100%; height: auto; }`，讓手機／平板正確排版。專案 `server/updates/public/notice.html` 已包含這些設定與繪本配色，可選擇替換現有網頁。
- 檔案以 UTF-8 儲存，包含 `<meta charset="utf-8">`。2026-11-04 已檢查線上 `/notice.html`：HTTP 200，內容為有效 UTF-8；現有頁面可直接使用。新版樣式範本尚未代為上傳。
- 頁面導覽限 `https://star.singtu.hk` 同源，不開啟 HTTP、外部網站、`file:`、`javascript:` 或其他 App scheme；圖片等子資源由網站本身控制。
- 網頁沒有遊戲 JavaScript bridge；App 不把遊戲存檔、錢包憑證、API Key 或商店交易注入網頁。不要在公開公告放機密資料。
- WebView 不支援的平台以原生離線文字顯示。離線備援仍只保留安全文字格式，上限 64 KiB、700 節點、18 層巢狀，下載逾時 8 秒；這些限制不會限制線上 WebView 的 HTML 大小及樣式。
- 新版 App 首次接入插件需重新建置；之後只改伺服器 HTML 即可。這次沒有執行 APK／IPA 建置、iOS Actions 或伺服器部署。

官方插件：[webview_flutter](https://pub.dev/packages/webview_flutter)。

## 開始頁美術與效果

開始按鈕及乾淨森林背景透過 APIXGo 的 `gpt-image-2.5-flare` 生成；按鈕已去背，文字由 Flutter 繪製。完整提示詞記錄於 `docs/START_SCREEN_ART_PROMPTS.md`。

角色使用既有透明素材，由 Flame 的位移／縮放效果及粒子元件實作呼吸、搖擺、輪流招呼與點擊跳躍。背景視差、透視旋轉、落地陰影及不同景深的螢光營造 2.5D 立體感，並非真正的 3D 模型。裝置減少動態效果設定啟用時會停止場景動畫；切到背景及閱讀公告時暫停場景。

開始頁的實際 Flutter 截圖與動畫可在 Windows 終端機重建：

```powershell
$env:FOREST_START_CAPTURE='1'
flutter test test/start_scene_test.dart
Remove-Item Env:FOREST_START_CAPTURE
python tool/export_start_preview.py
```

輸出位於 `output/preview/start-v2/`。這些是 Flutter 測試渲染的預覽，並非 iPhone／Android 實機錄影。
