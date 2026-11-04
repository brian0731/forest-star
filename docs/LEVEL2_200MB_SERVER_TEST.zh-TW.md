# 第 2 關「螢光秘林」：200 MB 以上伺服器更新測試

2026-11-04；客戶端 **1.10.1 / Build 21**；網址 `https://star.singtu.hk`；內容版本 `forest-level2-v1`。

## 已完成的內容

測試包有 **231,199,375 bytes，約 231.20 MB / 220.49 MiB**，共五個素材，不含用來湊大小的空白檔、重複 ZIP 或無效填充：

- 晚間營地 WebP：1024 × 1536。
- 第 2 關四路螢光秘林 WebP：804 × 766，四條路已按遊戲角色中心校正。
- `firefly-camp.mp3`：48 分鐘，營地用；320 kbps、44.1 kHz、立體聲。
- `firefly-adventure.mp3`：48 分鐘，冒險／守衛用；320 kbps、44.1 kHz、立體聲。
- `levels.json`：保留第 1 關，加入第 2 關「螢光秘林」。基礎耐久 125，三波 7／9／10 隻，第三波末尾為 Boss。

圖片經 APIXGo openai 分組的 `gpt-image-2.5-flare`，用開始畫面及原場景作參考生成；提示與後製紀錄在 `server/updates/examples/level2/ART_PROMPTS.md`。MP3 為本專案以程式原創作曲及加法合成的延伸測試版，沒有下載第三方歌曲、錄音或音色樣本。可重新產生，但聽感不代表真人樂團錄製。完整 MP3 已解碼驗證，合成訊號無削波。

兩首 48 分鐘高碼率版用來測試大檔。正式日常發行可改成較短或較低碼率版本，另建內容版本；不要覆寫這個已部署版本的檔案。

## 交付檔案

本機目錄 `C:\Users\user\Desktop\forest-star\Builds\Server`：

- `forest-star-level2-200mb.zip`：完整網站測試包，ZIP 大小 231,205,045 bytes。
- `update-v1-level2-build21.json`：啟用設定，最低 iOS／Android Build 21。
- `level2-package-report.json`：精確大小及 ZIP SHA-256。
- `LEVEL2-200MB-測試教學.md`：本說明的副本。
- `level2-battle-preview.png`、`level2-camp-preview.png`：實際 Flutter 畫面測試截圖。
- `MP3` 子資料夾：兩首完整 MP3 與各 24 秒試聽版。

圖片 WebP 同時在 Git 的 `server/updates/examples/level2/`；大型 MP3／ZIP 位於忽略目錄及 Build 交付目錄，**不放進 GitHub Git 倉庫或 APK／IPA**。

## 為甚麼需要新版 App

Build 20 上限為整包 50 MiB、單檔 20 MiB，不支援這包。Build 21 改為整包 512 MiB、音樂單檔 128 MiB，圖片仍限單檔 20 MiB、最大 4096 × 4096；新增 `field-level2` 及 `adventure-music` 固定用途，仍不下載程式碼。

媒體從 HTTP 串流直接寫入暫存檔，同時 SHA-256 校驗；磁碟寫入有背壓，不把 115 MB 的 MP3 整檔留在 Dart 記憶體。快取也透過檔案串流重驗，音樂只讀檔頭。逐檔下載，連線等待 15 秒、串流無新資料 20 秒、每檔最多 30 分鐘；可取消。失敗保留原有內容，重試從頭下載整包，**未做斷點續傳**。

保留上一版本以供回退。下載前建議使用 Wi-Fi、預留至少 1.2 GB 空間；磁碟錯誤會停止更新並保留原有內容，未接原生可用空間預檢。播放器從 App Support 的 MP3 路徑播放，失敗回到內附音樂。

## 上傳到 Linux VPS／Nginx

這次只產生本機交付包，**未登入或部署 VPS**。先安裝 Build 21；不要把大包的最低版本降成 20。

1. 將 ZIP 上傳至 VPS `/tmp/forest-star-level2-200mb.zip`。
2. SSH 執行以下指令；網站 root 若與範本不同，請替換。新的素材路徑必須不存在，避免覆寫已發布版本。

```bash
unzip -t /tmp/forest-star-level2-200mb.zip
test ! -e /tmp/forest-star-level2-incoming
mkdir /tmp/forest-star-level2-incoming
unzip /tmp/forest-star-level2-200mb.zip -d /tmp/forest-star-level2-incoming
sudo test ! -e /var/www/forest-star-updates/content/forest-level2-v1
sudo install -d -m 755 /var/www/forest-star-updates/content
sudo cp -a /tmp/forest-star-level2-incoming/content/forest-level2-v1 /var/www/forest-star-updates/content/
sudo find /var/www/forest-star-updates/content/forest-level2-v1 -type d -exec chmod 755 {} +
sudo find /var/www/forest-star-updates/content/forest-level2-v1 -type f -exec chmod 644 {} +
```

3. **先檢查素材，再切換設定。** Windows 專案根目錄可核對遠端內容與本機 catalog，每個檔案串流下載計算 SHA-256，不會把完整 MP3 放入記憶體：

```powershell
python tool/verify_update_server.py --local-catalog output/server/forest-level2-v1/content/forest-level2-v1/catalog.json
```

4. 上一步全部成功後，在 VPS 原子替換 manifest。這份設定使用 revision 3；如果你已另外發布更高 revision，先提高此值及日期。勿覆蓋你之後自行新增的公告或平台版本設定。

```bash
sudo cp /var/www/forest-star-updates/game/update-v1.json /tmp/forest-star-update-before-level2.json
python3 -m json.tool /tmp/forest-star-level2-incoming/game/update-v1.json > /dev/null
sudo install -m 644 /tmp/forest-star-level2-incoming/game/update-v1.json /var/www/forest-star-updates/game/update-v1.json.next
sudo mv /var/www/forest-star-updates/game/update-v1.json.next /var/www/forest-star-updates/game/update-v1.json
curl -fsS https://star.singtu.hk/game/update-v1.json
```

只修改靜態檔不需要 reload Nginx。Nginx `client_max_body_size` 限制的是上傳請求，並非玩家 GET 下載；SSH／SFTP 上傳此 ZIP 不靠此限制。不要覆寫既有 HTTPS 或其他網站設定。保持 `.mp3` 可靜態下載，內容檔有 `Content-Length`、版本路徑 immutable、manifest 不長時間快取。

5. Windows 再確認目前線上設定及五個素材：

```powershell
python tool/verify_update_server.py
```

## 手機驗收

1. 安裝 1.10.1 / Build 21，關閉再開啟 App，看到版本 `forest-level2-v1` 及約 220.5 MB 下載量。
2. 選下載，觀看百分比與 MB 前進。停止下載後仍可進遊戲；重新開啟再下載會從頭開始。
3. 完成後進入營地，看晚間場景、原有三個可觸控地點及小角色；啟用聲音，確認新 MP3 播放。
4. 正常通過第 1 關後進第 2 關，看螢光秘林、四條路、基礎耐久 125（若上陣提供耐久加成的夥伴會再增加）、三波敵人與末波 Boss。伺服器不會直接跳關或改寫玩家存檔。
5. 關閉網路重啟，已下載的內容應可使用；若已有比第 2 關更後的正式存檔，請用另一個測試安裝／測試裝置驗收，勿為測試直接刪除正式進度。
6. iPhone／Android 都確認音樂、靜音、返回前景及進出教學／廣告的暫停恢復。自動測試不等於手機實機驗收。

若有問題，先在新 revision 的 manifest 關閉 content 更新，或指回仍保留的 `forest-base-v1`（維持它原本的大小及 SHA-256）。關閉更新開關不會刪除玩家已下載的快取；要求回到舊素材時，應明確發布指回舊包的有效設定。

## 本機重新產生與測試

```powershell
python -m pip install numpy Pillow imageio-ffmpeg
python tool/compose_level2_music.py --theme camp
python tool/compose_level2_music.py --theme adventure
python tool/prepare_level2_update.py
$env:FOREST_LARGE_SITE = (Resolve-Path output/server/forest-level2-v1).Path
flutter test test/level2_package_test.dart
```

以上生成目錄須尚不存在，工具避免覆寫正式素材。圖片先使用 imagegen 技能 CLI 及 `ART_PROMPTS.md` 的兩個提示生成，輸出在 `output/imagegen/level2-v1/field.png` 與 `camp.png`。API 金鑰留在本機環境變數，不加入 App、網站或 Git。
