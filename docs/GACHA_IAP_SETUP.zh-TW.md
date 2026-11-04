# 星願轉珠：玩法、內購與 Linux VPS 設定

本次完成 Flutter 玩法、20 隻新寵物、官方內購插件及交易核驗服務的原始碼。沒有建立商店商品、部署 VPS、建置 APK／IPA 或執行 GitHub Actions；實際付款仍須完成下列設定及沙盒驗收。

## 遊戲內行為

- 進入營地後，右上角星光圖示或營地下方「星願轉珠」可進入轉珠頁。夥伴小屋可用左右箭頭查看 26 位夥伴，新寵物也可升級、進化、上陣四路守衛及在營地巡邏。
- 香港時間（UTC+8）每日 00:00 補滿 **5 次免費轉珠**，不累積；免費先用，之後可用已購買的次數。免費額度與獎品一起寫入本機存檔，重新開啟不重置。向後調整裝置日期不補次數；向前更改日期、刪除資料仍可繞過本機額度，這是離線方案的限制。若需要跨裝置及防改時鐘的每日限額，需另做伺服器登入與時間權威。
- 免費可離線使用；付費轉珠必須連線。付款不是每抽一次直接扣款：消耗型內購商品一次購買 **10 次轉珠**，之後逐次使用。不是訂閱，不以星糖扣款。價格完全取自商店，不在 App 寫死。
- 沒有保底，每次獨立隨機。寵物總機率 30%，新寵物 20 隻各 1.5%；星糖 20／40／80 的機率為 25%／15%／5%；彈珠 3／8／15 顆的機率為 15%／8%／2%，合計 100%。免費與付費相同，購買前及頁面上都提供機率。
- 首次抽中寵物即解鎖；重複寵物轉成該寵物 40 成長分，沿用 Lv.3／6 自動進化。彈珠超過 999 的部分以 1:1 轉星糖；星糖上限 999,999。
- 既有六位夥伴存檔會擴充至 26 格，保留原等級、成長、隊伍與資源。彈珠六籃仍對應原本六位；新寵物以星糖升級或重複抽取累積成長。
- 營地原本「重設進度」位置改為轉珠，避免誤按清掉已購買相關進度。

## 1. App Store Connect 商品

在 Bundle ID **`com.foreststar.foreststar`** 的 App 新增 App 內購買項目：

- 類型：**消耗型 Consumable**。
- 參考名稱：`星願轉珠 10 次`。
- 商品 ID：**`forest_star_draws_10`**（必須完全相同）。
- 顯示名稱及說明：`星願轉珠 10 次`／`增加 10 次星願轉珠機會；每次隨機獲得寵物、星糖或彈珠，不保證獲得寵物。`
- 選擇售價、銷售地區、當地化資料，加入轉珠頁審核截圖。首次內購需隨新版 App 送審；確保付費 App 合約、銀行及稅務資料已完成。

Apple 的購買確認視窗會顯示實際價格，測試時使用 TestFlight／Sandbox Apple Account。本專案用 `in_app_purchase` 的 StoreKit 2，將匿名錢包 UUID 作為 `appAccountToken`，後端必須核對它。

App Store Connect「使用者與存取權限 → 整合 → App 內購買項目」建立可用於 App Store Server API 的金鑰，取得 `.p8`、Key ID、Issuer ID。**不要將 `.p8` 放入 Flutter、Git 或公開網站；不要把 ASC 上傳金鑰一定可用視為前提，請確認其 API 權限。** Apple App ID 是 App 的數字 ID，不是 Bundle ID 或 Team ID。

從 [Apple PKI 官方頁面](https://www.apple.com/certificateauthority/) 取得 App Store Server Library 所需的 Apple Root CA 憑證（DER `.cer`），放進 VPS `secrets/apple-roots/`。使用官方庫驗證簽章與憑證鏈，不能只 Base64 解碼 JWS。

App Store Connect 設定 **App Store Server Notifications V2**：正式／沙盒通知 URL 均使用

`https://star.singtu.hk/api/gacha/notifications/apple`

退款／撤銷通知通過簽章驗證後，伺服器會扣回該筆 10 次；已消耗部分成為錢包負額，後續購買先抵銷負額。已發到離線遊戲的寵物／資源目前不回收。

## 2. Google Play 商品

在 Android 套件 **`com.foreststar.forest_star`** 新增單次商品（可消耗），商品 ID 同樣是 **`forest_star_draws_10`**，開通購買選項、售價及銷售地區。App 使用 Google Play Billing 官方付款畫面，不接受網頁付款。

在 Google Cloud 啟用 **Google Play Android Developer API**，建立服務帳戶 JSON，將此服務帳戶授予 Play Console 中這個 App 所需的訂單查詢／管理權限。伺服器呼叫 `purchases.products.get` 核驗 package／product、付款狀態、數量及 `obfuscatedExternalAccountId`，交易入帳後再由伺服器 `consume`。App 不會提前自動消耗，付款待處理或取消不發次數。

建立 Google Cloud Pub/Sub 主題，讓 Google Play 即時開發人員通知（RTDN）發布到該主題；建立 Push 訂閱：

- Endpoint：`https://star.singtu.hk/api/gacha/notifications/google`
- 啟用驗證，選擇 Push 專用服務帳戶。
- Audience：完全相同的 Endpoint URL。
- 服務環境的 `GOOGLE_PUSH_EMAIL` 填 Push 服務帳戶電郵，**不是** Play API 服務帳戶檔案路徑。

後端驗證 Google 簽署的 OIDC token、audience 及服務帳戶 email，僅對已知交易處理作廢／取消通知。未設定 Push 驗證資料時，Android 付費不會被標示為可用。

使用 Play 內部測試、授權測試帳戶及從 Play 安裝的正式簽章版本驗收，側載 APK 不代表可測正式內購。

## 3. 部署到既有 Linux VPS

使用 WinSCP／SFTP 將專案的 **`server/gacha/`** 上傳至 `/opt/forest-star-gacha/`，不要上傳本機 `node_modules`。保留現有靜態更新網站。

VPS 需有 Docker Engine 與 Compose plugin。在 VPS：

```bash
cd /opt/forest-star-gacha
cp .env.example .env
mkdir -p secrets/apple-roots
chmod 700 secrets
```

將 Apple `.p8` 存為 `secrets/apple.p8`、Google JSON 存為 `secrets/google-play.json`，上傳 Apple Root `.cer` 到 `secrets/apple-roots/`。容器使用 UID 1000；請確保它可唯讀存取這些檔案、其他非必要帳戶不可讀取。

```bash
sudo chown -R 1000:1000 secrets
chmod 700 secrets secrets/apple-roots
chmod 600 secrets/apple.p8 secrets/google-play.json
chmod 644 secrets/apple-roots/*.cer
```

用 `nano .env` 填入已建立的項目，未準備的平台留空：

```dotenv
DB_PATH=/data/gacha.sqlite
PORT=8081
APPLE_KEY_FILE=/run/secrets/apple.p8
APPLE_KEY_ID=你的KeyID
APPLE_ISSUER_ID=你的IssuerUUID
APPLE_APP_ID=你的數字AppID
APPLE_ROOT_CERTS=/run/secrets/apple-roots
ALLOW_APPLE_SANDBOX=true
GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/google-play.json
GOOGLE_PUSH_AUDIENCE=https://star.singtu.hk/api/gacha/notifications/google
GOOGLE_PUSH_EMAIL=你的Push驗證服務帳戶電郵
```

`ALLOW_APPLE_SANDBOX=true` 供 TestFlight／沙盒及 App Review 測試；若保留於正式服務，同一筆沙盒購買仍只發放一次，但沙盒與正式交易會進入同一錢包資料庫。若營運需要完全隔離，請另部署沙盒服務／資料庫並以獨立測試編譯設定切換 API，不要複製正式錢包資料。

```bash
chmod 600 .env
docker compose up -d --build
docker compose logs --tail=40
curl http://127.0.0.1:8081/health
```

沒有憑證的平台不開放付費。憑證存在不代表商店權限與商品已通過，仍須做真實沙盒交易。

## 4. 接入 Nginx HTTPS

在 Nginx `http {}` 區塊加入一次限流區定義：

```nginx
limit_req_zone $binary_remote_addr zone=forest_gacha:10m rate=3r/s;
```

再將 `server/gacha/nginx-location.conf` 的 `location /api/gacha/ { ... }` 放進目前 `star.singtu.hk` 的 **HTTPS server 區塊**。`proxy_pass` 結尾斜線會去除 `/api/gacha/` 前綴，讓 Node 收到 `/wallet` 等路徑。

```bash
sudo nginx -t
sudo systemctl reload nginx
curl https://star.singtu.hk/api/gacha/health
```

服務只映射至本機 `127.0.0.1:8081`，不要對外開放此埠；API 需 HTTPS，Nginx 不記錄存取日誌，不把 Authorization 或購買 token 寫入日誌。

## 5. 錢包、資料與備份

App 自動建立隨機 UUID 與 256-bit 私密錢包碼，保存在 Keychain／Android 安全儲存。它不以廣告 ID、姓名或電郵識別玩家。付款時把 UUID 傳給商店，以便核對交易屬於該錢包。後端只保存私密碼的 SHA-256、錢包 UUID、付費餘額、交易 ID／必要 Google token、時間、抽獎結果與流水號，SQLite 位於 Docker 的 `gacha-data` volume。

轉珠頁右上角鑰匙可複製私人備份碼及匯入舊錢包。備份碼不公開；其中的 UUID 及私密碼會經 HTTPS 驗證標頭傳送至自己的驗證服務，伺服器只儲存私密碼的雜湊。匯入先驗證，原錢包請先備份。備份碼可控制該錢包，不能分享。付費消耗品不是永久權益，商店 Restore 不會重新發放已消耗商品；**請保留錢包備份碼與 VPS 資料庫備份**。

新裝置匯入同一錢包可取回未用次數，並重播已購轉珠的獎品紀錄；只重播到該裝置尚未套用的流水號，不重複發獎。其餘關卡、免費抽獎及遊玩進度仍只在原裝置。沒有整個遊戲的跨裝置同步，也未加入 Apple／Google 帳戶登入。

Android 已停用一般 App 自動備份，避免還原到無法解密的錢包檔。iOS Keychain 可能在移除 App 後保留，系統／裝置移轉行為依平台設定而異。

資料庫備份前停止服務，將該 volume 的 `gacha.sqlite`、`gacha.sqlite-wal`、`gacha.sqlite-shm` 一起備份，或使用 SQLite online backup 工具建立一致性快照。不要只在執行中複製主檔。不要公開資料庫或放進 `/var/www/`。

## 6. 付款前必做的驗收

1. 每日恰好 5 次免費，重新開啟無法再領，香港午夜重置。
2. 新寵物出現在小屋，可升級、進化、四路編隊及巡邏；原本存檔內容保留。
3. 商店顯示正確當地價格，購買前可讀全部機率；取消、家長未批准或付款失敗不發次數。
4. 沙盒購買一包只增加 10 次；同一筆重送不加第二次。寵物不保證出現。
5. 付款後斷網、強制關閉、重開後「同步／補領」，不會重複入帳；轉珠中斷同一 request ID 只扣一次。
6. Apple／Google 發送測試通知成功；退款／撤銷後餘額扣回。確認通知監控正常，不可只有手動核驗。
7. 備份碼在另一裝置可匯入，已消耗的抽獎不重複套用到同一裝置。
8. 更新公開隱私政策、App Store 隱私資料及 Google Play Data safety／內購與隨機物品標示。實際受眾包含兒童，需在商店設定及審核說明如實申報，並以各商店的家長控制及購買批准流程測試。

自動測試為模擬商店與本機伺服器測試，不能代替 Apple／Google 沙盒或實機付款驗收。正式付款開通需商品、金鑰、伺服器及通知全部完成，本次未代為開通。

## 參考

- [Flutter 官方 in_app_purchase 插件](https://pub.dev/packages/in_app_purchase)
- [Apple App Store Server Library](https://github.com/apple/app-store-server-library-node)
- [Apple 審核規範：內購與隨機物品機率](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play 商品交易核驗](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products/get)
- [Google Play 即時開發人員通知](https://developer.android.com/google/play/billing/rtdn-reference)
- [Google Play 付款與隨機物品政策](https://support.google.com/googleplay/android-developer/answer/18265346?hl=en-GB)
