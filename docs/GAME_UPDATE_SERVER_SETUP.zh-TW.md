# 森星小隊：啟動檢查與圖片／音樂／關卡更新伺服器

更新：2026-11-03。指定網址：**https://star.singtu.hk**。主機：**Linux VPS + Nginx**。

這份教學可建立供 App 讀取的 HTTPS 更新網站，提供版本提示、公告，以及圖片、音樂、關卡 JSON。此階段交付伺服器範本、實際素材測試包及操作說明；**現有 iOS Build 19／Android Build 18 尚未實作啟動檢查及遠端素材載入**。網站上線後，仍須將下述客戶端流程寫進 Flutter，再透過商店發布一次新版。只上傳 JSON 不會讓已安裝的舊版自動獲得新功能。

本次從開發電腦檢查，`star.singtu.hk` 尚無法解析 DNS，因此未完成線上連通驗證，也未登入或修改你的 VPS。

## 1. 更新範圍

App 啟動先顯示開始畫面，背景檢查 `https://star.singtu.hk/game/update-v1.json`。無更新或斷線時，使用已驗證的本機資源，照常開始遊戲；有素材更新時顯示內容版本、下載大小及下載／稍後選項，下載驗證完成後，下次進入營地或下次啟動才切換。

可下載既有畫面使用的背景圖片、角色圖片、音樂及符合固定格式的關卡資料。關卡資料只能描述已隨 App 發布的敵人種類、四條路、數值及波次；不能包含 Dart、JavaScript、Lua、原生函式庫或可執行腳本。新增技能、物理算法、程式功能、SDK 或資料解析格式，需重新建置 App 並經商店更新。Apple 2.5.2 對下載會新增或變更功能的程式碼有限制，資料更新亦須符合已審核的功能及內容範圍。[Apple 審查規則](https://developer.apple.com/app-store/review/guidelines/#software-requirements)

**版本檢查不是自動安裝 App。** iOS 更新按鈕開啟本 App 的 App Store 頁面；TestFlight 測試者透過 TestFlight 更新。Google Play 版開啟商店頁面，未來亦可整合 Play 的應用程式內更新；本方案不從伺服器安裝 APK／IPA。[Android 更新說明](https://developer.android.com/guide/playcore/in-app-updates)

## 2. 已準備好的檔案

在 Windows 開啟 PowerShell：

```powershell
Set-Location 'C:\Users\user\Desktop\forest-star\Flutter\forest_star'
python tool/prepare_update_server.py
python tool/prepare_update_server.py `
  --site output/server/forest-base-v1 `
  --content-version forest-base-v1 `
  --zip ../../Builds/Server/forest-star-update-server-v1.zip
```

若範例包已由本次工作產生，可以直接使用 `C:\Users\user\Desktop\forest-star\Builds\Server\forest-star-update-server-v1.zip`。`--site` 必須指定**尚不存在**的目錄，避免覆寫已發布的素材版本；重新產生時改用新目錄。JSON 的範例有效日期也須依發布日調整。

壓縮包根目錄包含：

```text
index.html
404.html
health.json
_headers                      # Cloudflare Pages 才會讀；Nginx 使用自己的設定
game/update-v1.json
content/forest-base-v1/catalog.json
content/forest-base-v1/camp.webp
content/forest-base-v1/pinball-board.webp
content/forest-base-v1/forest-camp.wav
content/forest-base-v1/levels.json
```

測試包從本專案複製現有營地背景、彈珠台背景及森林背景音樂；`levels.json` 為固定格式示範，**不是已接上戰鬥引擎的正式關卡表**。打包工具自動計算每個檔案的位元組大小、SHA-256，以及素材目錄本身的 SHA-256。不要手填檔案雜湊。

## 3. DNS 與 VPS 前置設定

需要：VPS 的公用 IPv4、SSH 登入帳戶，以及 `singtu.hk` 的 DNS 管理權限。下列 `YOUR_VPS_IPV4`、`YOUR_SSH_USER` 都要換成你的實際值；密碼或 SSH 私鑰不放入 App／GitHub 公開檔案。

在網域 DNS 後台新增／核對：

```text
類型：A
名稱：star
內容：YOUR_VPS_IPV4
TTL：Auto 或供應商預設
```

若使用 Cloudflare DNS，首次排查可先選「DNS only」，HTTPS 成功後再開代理並使用 Full (strict)。沒有可用 IPv6 時，不要保留指向其他主機的 AAAA 記錄。不要把正在使用的其他網站記錄改成此 IP。

Windows 檢查：

```powershell
Resolve-DnsName star.singtu.hk
Test-NetConnection star.singtu.hk -Port 80
Test-NetConnection star.singtu.hk -Port 443
ssh YOUR_SSH_USER@YOUR_VPS_IPV4
```

雲端防火牆／Security Group 應允許 TCP 80、443；SSH 埠只供管理。若 VPS 已有防火牆，先核對原有 SSH 規則，再依你的環境新增網頁埠。以下指令以 Ubuntu 24.04 LTS 為例。

## 4. 安裝 Nginx 與上傳網站

VPS 的 SSH 終端：

```bash
sudo apt update
sudo apt install -y nginx unzip rsync snapd
sudo systemctl enable --now nginx
sudo mkdir -p /var/www/forest-star-updates/game /var/www/forest-star-updates/content
```

另開一個 Windows PowerShell，上傳壓縮包與範例設定：

```powershell
Set-Location 'C:\Users\user\Desktop\forest-star\Flutter\forest_star'
scp '../../Builds/Server/forest-star-update-server-v1.zip' YOUR_SSH_USER@YOUR_VPS_IPV4:/tmp/forest-star-update-server-v1.zip
scp server/updates/nginx.example.conf YOUR_SSH_USER@YOUR_VPS_IPV4:/tmp/forest-star-updates.conf
```

回 VPS 終端。若此網域已有 Nginx server block，先在原設定整合相應 `location`，不要新增兩份相同 `server_name`：

```bash
unzip /tmp/forest-star-update-server-v1.zip -d /tmp/forest-star-incoming-v1
sudo rsync -a /tmp/forest-star-incoming-v1/ /var/www/forest-star-updates/
sudo find /var/www/forest-star-updates -type d -exec chmod 755 {} +
sudo find /var/www/forest-star-updates -type f -exec chmod 644 {} +
sudo install -m 644 /tmp/forest-star-updates.conf /etc/nginx/sites-available/forest-star-updates
sudo ln -s /etc/nginx/sites-available/forest-star-updates /etc/nginx/sites-enabled/forest-star-updates
sudo nginx -t
sudo systemctl reload nginx
curl -i http://star.singtu.hk/health.json
```

`ln -s` 若顯示連結已存在，先確認它是否指向上述檔案，不需要重建。`nginx -t` 成功才 reload。上傳的網站根目錄應直接看到 `health.json`，不能多包一層 `public/` 或 `forest-base-v1/`。

提供的 Nginx 設定將 JSON 設為重新驗證快取，版本化素材設為長快取；不存在的檔案回傳 404，不把缺失 JSON 轉成首頁 HTML。預設關閉此服務的 Nginx access log；反向代理、Cloudflare 或主機商仍可能處理連線 IP／存取紀錄。

## 5. 啟用 HTTPS

先確定 DNS 指向這台主機，且外部可以連到 TCP 80、443。以下採 Certbot 官方 snap 安裝方式；若已安裝其他來源的 Certbot，沿用既有安裝方式，不重複安裝。

```bash
sudo snap install --classic certbot
sudo /snap/bin/certbot --nginx -d star.singtu.hk
sudo /snap/bin/certbot renew --dry-run
curl -I https://star.singtu.hk/health.json
```

互動時填寫管理員電郵並接受憑證服務條款，確認 HTTP 轉到 HTTPS。不要使用自簽憑證，也不要在 App 關閉 TLS 驗證或加入全域 HTTP 例外。[Certbot Nginx 安裝教學](https://certbot.eff.org/instructions?ws=nginx&os=snap)

## 6. 核對線上服務

Windows PowerShell：

```powershell
$updateBaseUrl = 'https://star.singtu.hk'
Invoke-RestMethod "$updateBaseUrl/health.json"
$updateConfig = Invoke-RestMethod "$updateBaseUrl/game/update-v1.json"
$updateConfig.content
$assetCatalog = Invoke-RestMethod $updateConfig.content.catalogUrl
$assetCatalog.files | Select-Object key, bytes, sha256
Invoke-WebRequest "$updateBaseUrl/content/forest-base-v1/camp.webp" -OutFile "$env:TEMP/forest-star-server-camp.webp"
Get-FileHash "$env:TEMP/forest-star-server-camp.webp" -Algorithm SHA256
```

最後的 SHA-256 應等於目錄中 `key: camp` 的值。`health.json` 應回傳 `status: ok`；更新檔與素材目錄應為 JSON，圖片應能正常開啟，音樂能下載播放。另測一條不存在的 `/game/not-found.json`，應回 404。

不要對 `/game/` 設定 HTML 登入頁、驗證碼或整站重新導向。若 Cloudflare WAF／Bot 規則對 App 的公開 JSON 請求發出互動挑戰，需為這些公開唯讀路徑調整規則；不需開放寫入 API。

## 7. 更新 JSON 欄位

`schemaVersion` 是解析格式版本，目前固定 `1`；`configRevision` 每次公告／設定發布遞增。`publishedAt`、`expiresAt` 使用含 `Z` 的 UTC 時間，建議效期 30 日；過期後 App 應忽略遠端提示，使用本機資料，不鎖住離線遊戲。

`platforms.ios.latestBuild`／`platforms.android.latestBuild` 分別對應 iOS `CFBundleVersion` 及 Android `versionCode`，用整數比較；不能拿 `1.10.0` 與 `1.9.1` 當字串排序。兩個平台的 build 編號獨立。範例 iOS 19 是已上傳 TestFlight 的建置，不代表已公開 App Store，因此 `promptEnabled` 預設 `false`。

`storeUrl` 只填自己的已上線商店頁面：iOS 使用 `https://apps.apple.com/.../id實際數字ID`；Android 使用 `https://play.google.com/store/apps/details?id=com.foreststar.forest_star`，也須先確認實際可下載。不可把 Bundle ID 當作 Apple 商店數字 ID。商店確認已對目標地區上線後，才開啟 `promptEnabled` 並更新 latestBuild。第一階段建議提供可略過的更新提示；`minimumBuild` 先保持 `1`，未實作且驗證更新流程前不使用強制更新。

`notice` 是純文字公告，支援繁中、英文、粵語；不解析 HTML 或腳本。`notice.id` 更新後，可讓新版 App 每個公告只主動顯示一次。

`content` 指向素材目錄，`catalogBytes` 與 `catalogSha256` 由打包工具產生。`minimumClientBuild` 範例為 `20`，是規劃中的下載器版本門檻，需換成實際完成並發布的客戶端建置。**範例 `content.enabled` 保持 `false`，等 Flutter 下載器實作與驗收通過後才開啟。**

## 8. 圖片、音樂及關卡資料如何發布

每一版使用全新路徑，例如 `/content/forest-base-v2/`。同一版本已發布的檔案不覆寫，舊路徑保留供離線玩家、尚未升級玩家及回退使用。

先替換專案內要發布的素材，或修改打包工具內的明確來源清單，再產生新版網站包：

```powershell
python tool/prepare_update_server.py `
  --site output/server/forest-base-v2 `
  --content-version forest-base-v2 `
  --zip ../../Builds/Server/forest-star-update-server-v2.zip
```

在產生的 `output/server/forest-base-v2/game/update-v1.json` 修改公告、configRevision、日期與適用客戶端門檻，再驗證：

```powershell
python tool/prepare_update_server.py --manifest output/server/forest-base-v2/game/update-v1.json
```

上述驗證後若再修改產生目錄，最初 ZIP 不會自動更新；部署時直接上傳修改後的檔案，或以 `Compress-Archive -Path output/server/forest-base-v2/* -DestinationPath ../../Builds/Server/forest-star-update-server-v2-final.zip` 重新打包。

把新包上傳 VPS、解壓到新的 incoming 目錄後，**先上素材，最後上更新檔**。以下 incoming 路徑依你的實際解壓目錄替換：

```bash
sudo rsync -a --ignore-existing /tmp/forest-star-incoming-v2/content/ /var/www/forest-star-updates/content/
# 確認 HTTPS 能讀到 v2 的 catalog.json，且各檔案大小及 SHA-256 正確。
sudo install -m 644 /tmp/forest-star-incoming-v2/game/update-v1.json /var/www/forest-star-updates/game/update-v1.json.next
sudo mv /var/www/forest-star-updates/game/update-v1.json.next /var/www/forest-star-updates/game/update-v1.json
```

同磁碟上的 rename 可避免 App 讀到半個 JSON。只改靜態檔不需 reload Nginx。回退時，以更高的 `configRevision` 發布指回舊素材路徑的設定，更新有效日期；舊版素材檔案必須仍存在。若修正素材內容，一律建立新 content version。

圖片保留現有畫風、長寬比例及透明背景；限制解碼像素，例如最高 4096 × 4096，避免小壓縮檔解碼後佔用過多記憶體。音樂可先沿用 WAV；正式版可測試 AAC／MP3 以減少下載量，iOS／Android 均需實機播放驗證。大檔案才考慮 Range 斷點續傳；入門版失敗後重新下載單一檔案。

關卡範例的 `lanes` 固定為 4；每關有既定的 `waves`，描述敵人數量、血量、速度、出生間隔及最後一隻是否為 Boss。客戶端須限制數值範圍，例如每波 1–100 隻、血量 1–100000、速度 1–300、間隔 0.2–10 秒；只允許既有敵人類型。不可直接把遠端數值無驗證地用於迴圈、陣列大小或獎勵發放。

## 9. Flutter 接入工作：下一階段需要完成

這一節是開發規格，**不是目前已生效的功能**。建議新增 `UpdateService`、`ContentRepository` 及開始畫面的下載進度面板。

1. 啟動時先讀內附資源及上次有效的 active content，不把網路放在 `runApp()` 前無限等待。開始畫面顯示「檢查更新／下載進度／稍後」；JSON 請求總逾時約 5 秒，失敗可略過。
2. 讀取平台實際版本：使用 `package_info_plus`；HTTPS 請求使用直接宣告的 `http` 或 `dart:io`，檔案目錄使用 `path_provider`，SHA-256 使用 `crypto`。目前 lockfile 中的間接依賴不能代替在 pubspec 宣告直接使用的插件。
3. 檢查 JSON schema、平台 applicationId、有效日期、大小上限、客戶端版本門檻及欄位型別。只讀 `star.singtu.hk` 的 HTTPS 設定／素材，重新導向也要核對來源；商店連結另外限制為 Apple／Google 官方主機及本 App。不要為每部裝置在 URL 加識別碼。
4. 限制更新 JSON 64 KiB、素材目錄 256 KiB、單檔例如 20 MiB、整包例如 50 MiB、同時下載最多 2 個。下載前顯示總量；行動網路可讓玩家稍後，沒有空間則繼續使用原包。
5. 目錄先按原始位元組驗證大小與 SHA-256，再解析；每個素材也驗證大小與 SHA-256。Hash 可偵測檔案不一致，不能取代 HTTPS，也無法在網站被控制時證明發布者身分。需要更高保證時，再對目錄加入數位簽章及 App 內固定公鑰。
6. 下載至 App Support 的 `content/staging/版本/`，拒絕 `..`、絕對路徑、重複 logical key、未知副檔名及超額串流。全部驗證成功後，以完整版本目錄及暫存指標檔 rename 切換 active；保留上一個有效版本。第一版使用逐檔下載，不接收任意 ZIP 解壓。
7. 不在射球、戰鬥或教學中途熱換圖片。等返回開始畫面／下次啟動重建場景後載入新版，確保圖像、碰撞、去背資料與音樂屬於同一套版本。
8. 改造 `StoryArt`：目前只經 `rootBundle.load()` 且 `_loading` 僅執行一次；新增由 ContentRepository 取得位元組的入口並保留 rootBundle fallback。CampLocation 在建立時會計算圖片 alpha 命中範圍，更換角色／建築圖後須重建，不可只替換圖片 Map。
9. 改造 `AppAudio`：下載音樂用 `DeviceFileSource`，內附音樂保留 `AssetSource`。先停止／釋放舊播放器，再在場景切換後使用新檔。教學女聲仍用裝置 TTS，素材更新不改變朗讀引擎。
10. 改造 `Combat`／`GameState`：目前波次公式在 `lib/game.dart` 寫死，關卡進度亦限制 1–10。新增固定 schema 的 LevelDefinition 驗證及已發布關卡查詢，保留原本內附十關及存檔相容性；增加超過十關時，須在首個支援版本同步處理進度上限與舊存檔，不是只上傳 JSON。
11. 避免公告、版本提示與 AdMob UMP 同時彈出：在現有 `_dialogOpen` 及 `setExternalOverlay(source: ...)` 流程序列處理；廣告獎勵仍只由 earned-reward 回呼發放，不用 JSON 指令直接加彈珠。
12. 首次接入需上傳新 App build；審查備註說明下載的是媒體與固定格式關卡資料，提供可用測試端點。隱私政策補上自有更新網站／VPS 主機商處理 IP 及連線資料的用途、保存做法；尚未確定主機商前不聲稱完全沒有伺服器紀錄。

建議驗收：飛航模式啟動、5xx／404／錯誤 JSON、過期設定、錯誤 Hash、下載中斷／關閉 App、空間不足、舊版 schema、素材回退、存檔保留、四路關卡數值限制、iPhone／Android 圖片及音樂播放，以及廣告／教學彈窗互斥。

## 10. 若日後改用 Cloudflare Pages

目前主方案是既有 VPS，不需要購買新主機。若希望改為託管靜態檔，可將同一份 public 網站包用 Pages Direct Upload 上傳，再在 Pages 的 Custom domains **先加入 `star.singtu.hk`**，依指示調整 DNS；不要只改 CNAME 卻沒有在 Pages 綁定網域。選擇 Direct Upload 的專案，日後若要切換 Git 整合，需另建專案。

Pages 以 `_headers` 提供此包的快取規則，Nginx 則讀 `nginx.example.conf`。官方文件目前列出單一 Pages 素材檔上限 25 MiB，大型音樂檔需另外採 R2 或沿用 VPS。上傳前再次核對當時方案限制。

參考：[Nginx 靜態檔案](https://nginx.org/en/docs/beginners_guide.html#static)、[Pages Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/)、[Pages Header 設定](https://developers.cloudflare.com/pages/configuration/headers/)、[Pages 自訂網域](https://developers.cloudflare.com/pages/configuration/custom-domains/)、[Pages 限制](https://developers.cloudflare.com/pages/platform/limits/)。

## 11. 你現在先完成的工作

1. 在 DNS 後台把 `star` 的 A 記錄指向 VPS。
2. 用 SSH 安裝／設定 Nginx，上傳本次 ZIP，開通 80／443 及有效 HTTPS 憑證。
3. 確認 `https://star.singtu.hk/health.json` 與 `/game/update-v1.json` 可從手機網路直接開啟。
4. 保持 `content.enabled: false`，完成 Flutter 客戶端接入及實機測試後才啟用。

伺服器唯讀端點不需要把管理密碼提供給玩家。沒有玩家帳戶、排行榜或雲端存檔需求時，第一階段不需要資料庫、登入服務或公開管理 API。
