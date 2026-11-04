# 天空冒險音樂與守衛第 3–10 關

完整上傳步驟及更新包說明：[SERVER_SKY_GUARD_UPDATE.zh-TW.md](SERVER_SKY_GUARD_UPDATE.zh-TW.md)。本批素材僅由 server update 下載，不會打包進 App。

## 遊戲更新

- 營地：`server/updates/source/sky-v2/sky-camp-v2.mid`，72 BPM、3/4 拍、約 80 秒。
- 冒險：`server/updates/source/sky-v2/sky-adventure-v2.mid`，80 BPM、3/4 拍、72 秒。
- MP3 位於 `server/updates/media/forest-sky-guard-v2/`，由啟動更新頁驗證及快取。兩首均為本專案新編旋律，使用長笛、豎琴、柔和弦樂、大提琴及少量鋼片琴；沒有使用《天空之城》的旋律、錄音或第三方 MIDI。
- Android/iOS 實際循環播放同名 `.mp3`：44.1 kHz 立體聲、192 kbps，避免手機內建 MIDI 音源差異。`.mid` 保留供修改配器。
- 8 種操作音效重新製作，降低碰撞、射擊及按鍵聲的尖銳感與播放音量。靜音、切換頁面、App 背景暫停邏輯保留。

守衛第 3–10 關依序為：竹溪晴谷、楓葉山徑、霜雪松林、水晶幽谷、金沙綠洲、熔光花園、雲海浮島、星穹聖域。每關有獨立背景及對應環境效果；畫面外圍也採用同關場景。四條道路、敵人行進方向及戰鬥規則不變。

場景正式資產：`server/updates/media/forest-sky-guard-v2/guard-stage-3.webp` 至 `guard-stage-10.webp`，每張 804 × 766。APIXGo 原始生成圖及完整提示詞暫存於 `output/imagegen/guard-stages-v1/`；可提交的提示詞記錄為 [GUARD_STAGE_ART_PROMPTS.md](GUARD_STAGE_ART_PROMPTS.md)。生成使用 APIXGo openai 分組的 `gpt-image-2.5-flare`，經 imagegen fallback CLI `edit` 執行。

## 預覽與重製

- 背景總覽：`output/preview/guard-stages-v1/contact-sheet.jpg`。
- Flutter 真實戰鬥截圖：`output/review/guard-stages-v1/stage-3.png` 至 `stage-10.png`。
- 24 秒音樂試聽：`output/audio/sky-v2/sky-camp-v2-preview.mp3`、`sky-adventure-v2-preview.mp3`。
- 音訊長度、音量、循環接點及 SoundFont SHA-256：`output/audio/sky-v2/music-report.json`。

音樂生成需 Python 3.12（`tinysoundfont==0.3.7` 的 Windows wheel）：

```powershell
python -m pip install tinysoundfont==0.3.7 mido numpy scipy imageio-ffmpeg
python tool/compose_sky_music.py
```

本機 Python 3.13 沒有該套件的預編譯 wheel；可改用 Codex bundled Python 3.12 或其他 Python 3.12 環境。生成只在開發電腦執行，不會在 App 下載或執行 Python。

插畫處理及驗證：

```powershell
python tool/prepare_guard_stage_art.py
$env:FOREST_GUARD_THEMES_CAPTURE = '1'
flutter test test/guard_themes_test.dart
Remove-Item Env:FOREST_GUARD_THEMES_CAPTURE
flutter test test/audio_test.dart
```

## 樂器音源記錄

渲染採用 Chris Collins 的 [GeneralUser GS](https://www.schristiancollins.com/generaluser.php)，版本 2.0.3、License v2.0。上游條款允許私人及商業音樂製作；條款同時記載部分早期取樣來源的不確定性，完整內容已保留於 `server/updates/source/sky-v2/GeneralUser-GS-LICENSE.txt`。這是上游提供的授權說明，並非額外保證。SoundFont 本體只在 `output/audio/sky-v2/` 作為渲染輸入，沒有加入 App。

本次使用的 SoundFont SHA-256：`9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe`。

渲染工具 [TinySoundFont Python bindings](https://pypi.org/project/tinysoundfont/) 採 MIT 授權，只作開發用途。樂譜及編曲可由 `tool/compose_sky_music.py` 重製。

## 伺服器更新相容性

新客戶端接受以下 catalog key：

- `field-level3` 至 `field-level10`：`kind: image`，對應各關圖片；建議保持 804 × 766 及四路中心 Y = 92、278、464、650。
- `camp-music-v2`、`adventure-music-v2`：`kind: audio`，支援 MP3/WAV/M4A，分別供營地／冒險循環播放。
- `sfx-select-v2`、`sfx-launch-v2`、`sfx-bounce-v2`、`sfx-reward-v2`、`sfx-battle-v2`、`sfx-hit-v2`、`sfx-win-v2`、`sfx-fail-v2`：`kind: audio`，8 種柔和音效。

舊 `camp-music`、`adventure-music` 仍可被 catalog 解析，但新客戶端不會以這兩個舊 key 覆蓋新音樂，避免已下載的舊測試長音軌蓋過這次更新。若要伺服器換曲，請使用上述 `-v2` key，並重新產生 catalog 檔案大小、SHA-256 及 manifest 的 catalog 大小、SHA-256。舊客戶端不認識新增 key；新 catalog 應提高 `minimumClientBuild`，在新 App 版本發佈後才啟用。

最低客戶端 build 23（1.12.0）。未下載新音樂或快取播放失敗時保持安靜；沒有 App 內建的新 MP3 副本。未下載場景時使用基本場景，下載完成後可離線讀取新圖片、音樂及音效。這次只準備本機專案與可上傳更新包，沒有部署 VPS、執行 GitHub Actions 或產生新 APK。
