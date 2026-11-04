# 森星小隊：啟動檢查與圖片／音樂／關卡更新伺服器

更新：2026-11-04。指定網址：**https://star.singtu.hk**。主機：**Linux VPS + Nginx**。

**Build 21 大包更新：** 第 2 關螢光秘林、兩張圖片及兩首 MP3 的 220.49 MiB 伺服器測試包，見 [200 MB 測試教學](LEVEL2_200MB_SERVER_TEST.zh-TW.md)。Build 21 改為串流下載／校驗，音樂單檔 128 MiB、整包 512 MiB；以下 Build 20 的 50 MiB／整檔下載限制只適用於舊版。新包最低客戶端必須保持 21。

**Flutter 1.10.0（Build 20）已加入啟動更新頁、下載百分比／大小、校驗、離線回退及遠端圖片／營地音樂／固定格式關卡載入。** iOS Build 19／Android Build 18 等舊版仍須先安裝新版，才有下載能力。每次啟動進入遊戲前檢查；不在遊玩途中更換素材。

2026-11-04 已從開發電腦成功讀取 HTTPS 設定、目錄及四個素材，核對共 6,619,037 bytes 的大小與 SHA-256。**線上 `content.enabled` 目前仍為 `false`**，所以新版會顯示檢查完成，不會下載。未登入或修改你的 VPS；啟用方法見下節。

## 0. 網站已上線：現在啟用 Build 20 測試包

本機已準備 `C:\Users\user\Desktop\forest-star\Builds\Server\update-v1-enable-build20.json`，保留線上素材版本與校驗碼，將 `content.enabled` 設為 `true`、提高 `configRevision` 並更新有效日期；兩個平台最低客戶端仍為 Build 20。不會開啟商店更新提示。

先在手機安裝新版，再將此檔上傳到 VPS 的 `/tmp/update-v1-enable-build20.json`。SSH 登入後執行（網站實際 root 若不同，請替換）：

```bash
python3 -m json.tool /tmp/update-v1-enable-build20.json > /dev/null
sudo install -m 644 /tmp/update-v1-enable-build20.json /var/www/forest-star-updates/game/update-v1.json.next
sudo mv /var/www/forest-star-updates/game/update-v1.json.next /var/www/forest-star-updates/game/update-v1.json
curl -fsS https://star.singtu.hk/game/update-v1.json
```

重新開啟 App，點「下載森林更新」，觀看約 6.3 MiB 的下載進度；成功後點「進入遊戲」。此初始包沿用現有圖片和音樂，因此畫風相同，更新狀態會顯示 `forest-base-v1`。下次啟動會驗證快取並略過重複下載；飛航模式仍可使用它。測試完成後再公開推送新版。更新後的隱私政策 HTML 亦須同步到公開政策網址，並確認 VPS 日誌設定。

若要重新核對線上素材及產生新的本機啟用檔，在 Flutter 專案根目錄執行：

```powershell
python tool/verify_update_server.py --enable-manifest ../../Builds/Server/update-v1-enable-build20.json
python tool/prepare_update_server.py --manifest ../../Builds/Server/update-v1-enable-build20.json
```

這些指令只讀網站並寫本機檔案，**不會部署到 VPS**。設定約 30 天後到期，維運時須刷新日期；過期後 App 繼續使用已下載或內附內容。

## 1. 更新範圍

App 啟動先顯示森林更新頁，檢查 `https://star.singtu.hk/game/update-v1.json`。無更新或斷線時，可使用已驗證的本機資源進入遊戲；有更新時顯示內容版本、下載大小及下載／稍後選項，整包驗證成功後，按「進入遊戲」即使用新版。檢查、下載或校驗期間亦可略過，繼續使用原有內容。

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

測試包從本專案複製現有營地背景、彈珠台背景及森林背景音樂；`levels.json` 已接上 Build 20 戰鬥引擎，示範覆寫第 1 關的三波數據，其餘九關沿用內附公式。打包工具自動計算每個檔案的位元組大小、SHA-256，以及素材目錄本身的 SHA-256。不要手填檔案雜湊。

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

`notice` 保留繁中、英文、粵語欄位；目前更新頁顯示 `zh-Hant` 純文字，不解析 HTML 或腳本。點主按鈕進入遊戲後記錄 `notice.id`，避免重複顯示同一公告。

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

圖片保留現有畫風、長寬比例及透明背景；限制最高 4096 × 4096。音樂可用 WAV／MP3／M4A（需實機驗證），目前只有 `camp-music` 對應營地背景音。第一版失敗後重新下載整包，未實作斷點續傳。

關卡範例的 `lanes` 固定為 4；每關有既定的 `waves`，描述敵人數量、血量、速度、出生間隔及最後一隻是否為 Boss。客戶端須限制數值範圍，例如每波 1–100 隻、血量 1–100000、速度 1–300、間隔 0.2–10 秒；只允許既有敵人類型。不可直接把遠端數值無驗證地用於迴圈、陣列大小或獎勵發放。

## 9. Flutter Build 20 已實作的流程

`lib/update_page.dart` 在遊戲開始畫面之前顯示森林更新頁。`package_info_plus` 讀實際 build、`path_provider` 取得 App Support、`http` 下載、`crypto` 校驗、`url_launcher` 開啟有效商店連結。AdMob／UMP 在進入遊戲後才開始處理，避免與更新畫面同時出現。

`lib/content_updates.dart` 只接受 `star.singtu.hk` 的 HTTPS，拒絕重新導向、外站、路徑穿越、未知 logical key、重複檔名／key、錯誤型別及過期設定。上限為 manifest 64 KiB、catalog 256 KiB、單檔 20 MiB、整包 50 MiB；逐檔下載，檔案整體逾時 45 秒、串流閒置逾時 10 秒，JSON 整體逾時 8 秒。可隨時略過，不強制連線。

下載在 App Support 的 `forest-content-v1/staging-*`，整包大小與 SHA-256、圖片實際解碼／像素、音樂檔頭及關卡格式均通過才切換 `active.json`。保留 active 與 previous 兩套，安裝成功後清理其他版本；失敗不覆寫原 active。啟動會重新驗證快取，損壞時嘗試 previous，再使用內附內容。未做斷點續傳；重試重新下載整包。

`StoryArt.load(content: ...)` 在建立 Flame 場景前套用圖片，未列入更新的圖沿用內附素材；後續場景呼叫 load 不會意外改回舊圖。營地建築的 alpha 命中區隨新場景重新建立。圖片更新仍須符合既有素材的比例、透明背景及內容用途。

可用圖片 key：`camp`、`board`、`room`、`battle`、`field`、`location0`–`location2`、`friend0`–`friend5`、`marble0`–`marble3`、`nav0`–`nav3`、`frame-paper`、`frame-green`、`frame-cream`、`frame-selected`。副檔名 PNG／WebP／JPG，最大 4096 × 4096。

`AppAudio` 的 `camp-music` 使用下載的 WAV／MP3／M4A；播放失敗回到內附營地音樂。其他場景音樂、音效及裝置女聲教學不變。`LevelBook` 接受 1–10 關、每關四條路及三波，`Combat.begin()` 固定本場關卡設定，未提供的關卡沿用內附公式。資料不能新增技能、程式或發放任意廣告獎勵。

新增測試覆蓋關閉下載／舊客戶端、完整安裝與離線還原、錯誤 SHA-256、重試、中途取消、損壞快取回退及修復、重新導向／外站／過期設定／非法檔案、圖片解碼、關卡範圍與戰鬥接入、小螢幕下載按鈕及實際百分比。也可擷取線上完整包，在同一下載器中測試解碼與套用：

```powershell
python tool/verify_update_server.py --capture output/review/live-update-site
$env:FOREST_LIVE_SITE = (Resolve-Path output/review/live-update-site).Path
flutter test test/content_updates_test.dart
```

實機仍需驗證：Android／iPhone 首次下載、飛航模式、下載途中離開、圖片觸控位置、營地音樂播放、原存檔保留及 AdMob／教學流程。本機測試與 CI 不等於實機驗收。

## 10. 若日後改用 Cloudflare Pages

目前主方案是既有 VPS，不需要購買新主機。若希望改為託管靜態檔，可將同一份 public 網站包用 Pages Direct Upload 上傳，再在 Pages 的 Custom domains **先加入 `star.singtu.hk`**，依指示調整 DNS；不要只改 CNAME 卻沒有在 Pages 綁定網域。選擇 Direct Upload 的專案，日後若要切換 Git 整合，需另建專案。

Pages 以 `_headers` 提供此包的快取規則，Nginx 則讀 `nginx.example.conf`。官方文件目前列出單一 Pages 素材檔上限 25 MiB，大型音樂檔需另外採 R2 或沿用 VPS。上傳前再次核對當時方案限制。

參考：[Nginx 靜態檔案](https://nginx.org/en/docs/beginners_guide.html#static)、[Pages Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/)、[Pages Header 設定](https://developers.cloudflare.com/pages/configuration/headers/)、[Pages 自訂網域](https://developers.cloudflare.com/pages/configuration/custom-domains/)、[Pages 限制](https://developers.cloudflare.com/pages/platform/limits/)。

## 11. 你現在需完成的工作

1. 安裝 Build 20，在第 0 節啟用設定後測試下載、離線啟動、圖片及音樂播放。
2. 將更新後的隱私政策 HTML 同步到公開網址，確認 VPS 主機商、日誌及保存設定，按實際資料處理更新商店隱私申報。
3. 後續素材先上傳到新版本目錄，驗證可讀及雜湊後才原子替換 `game/update-v1.json`；持續刷新有效日期。

伺服器唯讀端點不需要把管理密碼提供給玩家。沒有玩家帳戶、排行榜或雲端存檔需求時，不需要資料庫、登入服務或公開管理 API。
