# 天空配樂與守衛第 3–10 關：伺服器更新部署

## 本次改動

新配樂、8 種柔和操作音效、8 張守衛場景圖片全部由 `https://star.singtu.hk` 的內容更新下載，不會放入 Flutter App 資產。App 仍保留基本遊戲圖片，以及大招專用的兩個音效；落葉、飄雪、火星、星光等動態效果由 Flame 即時繪製。

內容版本 `forest-sky-guard-v2`，共 21 個檔案、6,958,250 bytes（約 6.64 MiB）。這是完整快照，包含原有營地、第 2 關圖片和關卡資料，取代舊 200 MB 測試音樂。原創 MIDI 以長笛、豎琴、弦樂編曲；手機播放由 MIDI 渲染的 MP3，確保 Android/iOS 音色一致。可編輯 `.mid` 和音源授權留在 `maintainer-sources/`，不需 App 下載。

最低客戶端為 **1.12.0 / build 23**，Android/iOS 相同。舊 App 需要先更新一次才能使用新下載鍵值；之後同類圖片、音樂、音效及關卡資料可只更新伺服器。新增遊戲邏輯、粒子算法仍須發佈 App。這次未自動輸出 APK、未啟動 iOS Actions、未連線寫入 VPS。

## 檔案位置

- 專案素材：`server/updates/media/forest-sky-guard-v2/`，位於 Flutter `assets/` 之外。
- 原創 MIDI、音源授權：`server/updates/source/sky-v2/`。
- 舊音樂開發檔：`server/updates/source/legacy-audio/`，不會打包進 App 或本次下載。
- 可上傳 ZIP：`Builds/Server/forest-star-sky-guard-v2.zip`，位於 `forest-star` 工作區的 Builds 目錄。
- ZIP 只有 `content/`、`game/update-v1.json`、維護用來源及說明。**不含首頁、notice.html、商店或付款伺服器檔案。**

## 上傳 VPS：內容先上，manifest 最後啟用

1. 在電腦解壓 ZIP。使用 WinSCP/SFTP 上傳整個 `content/forest-sky-guard-v2/` 到網站根目錄的 `content/` 下。範例網站根目錄是 `/var/www/forest-star-updates`；請以目前 Nginx 的 `root` 為準。不要直接用整包覆蓋網站根目錄。
2. 此時先不要覆蓋 `game/update-v1.json`。在 Windows 專案目錄驗證公開網站每個檔案的大小及 SHA-256：

```powershell
python tool/verify_update_server.py --local-catalog server/updates/media/forest-sky-guard-v2/catalog.json
```

必須看到 `Catalog verified before activation`，共 6,958,250 bytes。404、校驗失敗或重新導向均需先修正。

3. 保留網站現有 `game/update-v1.json` 備份。ZIP 的新 manifest 以製作時的線上設定為基礎，保留商店版本欄位；如製作後你曾修改商店連結、版本提示或其他設定，先合併那些欄位。新包的 `content` 區塊、catalog 大小及 SHA-256 必須成套使用。檢查 `publishedAt`、`expiresAt`（製作後 90 日）仍有效，`configRevision` 大於目前線上版本。
4. 將 ZIP 的 `game/update-v1.json` 上傳為同目錄 `update-v1.next.json`；在 VPS 用原子更名啟用。以下路徑是範例，時間戳記備份名稱每次應不同：

```bash
cd /var/www/forest-star-updates
sudo cp -p game/update-v1.json game/update-v1.backup-20261104.json
sudo chmod 644 game/update-v1.next.json
sudo mv game/update-v1.next.json game/update-v1.json
```

靜態檔案更換不需要重啟 Nginx。`/game/` 應為 `Cache-Control: no-cache`，`/content/` 可用 immutable 長快取。若有 CDN，清除 `/game/update-v1.json` 的快取。

5. 再驗證啟用後的完整下載：

```powershell
python tool/verify_update_server.py
```

確認 `Live content enabled: True`，以及 `forest-sky-guard-v2`。更新包不會改動 HTML 告示板；告示板仍是 `https://star.singtu.hk/notice.html`。

## 手機驗收

1. 安裝 build 23 或之後的 App。開啟遊戲，在原有森林更新頁下載內容，進度條會顯示已下載大小。
2. 進營地播放新配樂，切換冒險後換曲；按鍵、發射、碰撞、獎勵、戰鬥、受擊、勝負使用較柔和音效。靜音和背景暫停仍有效。
3. 守衛第 3–10 關應依序出現竹溪、楓葉、雪林、水晶、綠洲、熔光、雲海、星穹背景及對應粒子效果。正常過關即可解鎖，不會因更新清除進度。
4. 下載後關閉 App、開飛航模式再開，確認圖片、配樂和音效仍從本機快取讀取，沒有串流或再次下載。
5. 未下載或下載失敗時仍可使用基本遊戲場景；新配樂及柔和操作音效會等待有效下載，不會偷偷使用 App 內建副本。下載損毀時不啟用新包，沿用之前有效快取。刪除 App／清除資料會清掉快取，需要重新下載。

## 日後更新與回復

每次改素材都建立新版本目錄，例如 `forest-sky-guard-v3`，勿覆寫已公開的 v2 檔案。客戶端按內容版本識別更新，且 CDN 可能保留舊檔。複製打包工具並修改 `VERSION`、來源目錄及 `levels.json` 的 `contentVersion`，重新計算所有大小與 SHA-256，再執行上述兩階段部署。完整快照需保留要繼續提供的營地、第 2 關、兩首音樂及全部音效鍵值。

回復時將已備份且未過期的 manifest 恢復為 `game/update-v1.json`；保留舊內容目錄。已下載的 App 會在下次檢查時切回該完整版本。舊 200 MB 包仍會觸發大型下載，通常應優先修復並發佈新版本。App 保存上一個有效快取，檔案不完整／校驗失敗不會覆蓋有效包。

## 在開發電腦重製

以下指令只準備本機檔案，不會部署。`--site` 和 `--zip` 必須用尚未存在的路徑；工具會從現有伺服器讀取 manifest，保留商店設定，再產生新的候選 manifest。

```powershell
python tool/prepare_sky_guard_update.py --site C:/Users/user/Desktop/forest-star/Builds/Server/forest-star-sky-guard-v2-new --zip C:/Users/user/Desktop/forest-star/Builds/Server/forest-star-sky-guard-v2-new.zip
flutter test test/server_media_pack_test.dart test/guard_themes_test.dart test/audio_test.dart
```

只重算專案內 catalog：`python tool/prepare_sky_guard_update.py --catalog-only`。如要以已檢查的 JSON 為基礎，另加 `--base-manifest <檔案>`。測試使用真正的 21 個素材透過模擬 HTTPS 下載，檢查校驗、離線回復、舊客戶端隔離、損毀拒收，以及 Flutter 資產清單沒有這批素材；不會對正式伺服器寫入。
