# 森星小隊 · Flutter / Flame

森林告示板已改用官方 `webview_flutter`，開始頁預覽與展開頁直接載入 `https://star.singtu.hk/notice.html`，支援網站 HTML／CSS／JavaScript、載入進度、重新整理與離線文字備援。公告更新不需要重打包；本次插件接入仍需下次手動建置新版 App 才會生效。詳見 [WebView 告示板設定](docs/NOTICE_BOARD_SETUP.zh-TW.md)。

星願轉珠：每天香港時間 00:00 補滿 5 次免費，新增 20 隻去背寵物（夥伴共 26 位），也可抽到星糖或彈珠。寵物合計 30%／每隻 1.5%，星糖 45%，彈珠 25%；重複寵物轉為 40 成長分。免費用完後使用 App Store／Google Play 內購的「10 次轉珠」消耗品，正式價格由商店提供。已加入官方 `in_app_purchase`、交易核驗後端、錢包備份及斷線補領；**正式付費尚未開通**，請先完成 [內購及 VPS 設定](docs/GACHA_IAP_SETUP.zh-TW.md) 與沙盒驗收。角色提示詞見 [新寵物素材](docs/PET_ART_PROMPTS.md)。

開始頁加入可由伺服器更新的 HTML 告示板、APIXGo `gpt-image-2.5-flare` 生成的開始按鈕／森林背景，以及 Flame 透明角色互動、螢光粒子、視差與透視效果。公告檔案與 VPS 上傳步驟見 [告示板設定](docs/NOTICE_BOARD_SETUP.zh-TW.md)。目前為原始碼更新，尚未建置新版 APK／IPA 或部署公告。

1.10.1（Build 21）支援超過 200 MB 的伺服器內容包：圖片、兩首原創 MP3 及第 2 關「螢光秘林」。下載／校驗改為串流，整包上限 512 MiB，音樂單檔 128 MiB。220.49 MiB 測試包、媒體來源、VPS 上傳與驗收見 [第 2 關大包測試教學](docs/LEVEL2_200MB_SERVER_TEST.zh-TW.md)。媒體不放進 APK／IPA 或 Git。

1.10.0（Build 20）加入 `https://star.singtu.hk` 啟動更新頁：實際下載百分比／大小、SHA-256 校驗、保留上一版本、離線進入遊戲。伺服器部署及操作見 [SERVER 設定教學](docs/GAME_UPDATE_SERVER_SETUP.zh-TW.md)。Build 20 不支援上述大包。

遊戲教學：開始畫面的「新手教學」，或遊戲左上角的學士帽圖示，可重播十步互動教學。使用 `tutorial_coach_mark` 聚焦實際遊戲位置，在獨立練習世界示範彈珠、六籃育成、升級、進化、四路守衛及免費補給，不寫入正式存檔。詳見 [教學及裝置朗讀設定](docs/GAME_TUTORIAL.zh-TW.md)。

iOS / TestFlight / App Store：請參閱 [GitHub Actions 上架設定教學](docs/IOS_GITHUB_ACTIONS_SETUP.zh-TW.md)，內含 iOS 工程、Apple 簽章、Secrets 與完整 workflow 範本。

iOS Bundle ID 為 `com.foreststar.foreststar`，採 iOS 15 起、iPhone 直向版面。Actions 的 `iOS - Build and TestFlight` 會依 Secrets 中的 App Store profile 配置簽章、建置 IPA，並可上傳 App Store Connect。Build 19 起，Actions 使用 `config/admob.ios.production.json` 的正式 iOS 獎勵廣告；本機預設及 Android 仍使用官方測試廣告。設定見 [iOS AdMob 接入](docs/IOS_ADMOB.zh-TW.md)。TestFlight 上傳與 App Store 公開發佈分開進行。

此 GitHub 倉庫的根目錄就是 Flutter 專案，不包含外層 Unity 工程、Prototype 或建置快取。將倉庫下載後，在根目錄執行：

```powershell
flutter pub get
flutter run
flutter test
```

預設使用 Google 官方測試廣告，沒有收益。正式版本請複製 `config/admob.production.example.json` 為 `config/admob.production.json`，填入自己 AdMob 的 App ID 與獎勵式廣告單元 ID，並確認受眾設定，再執行：

```powershell
./tool/build_admob_release.ps1 -ConfigPath ./config/admob.production.json
```

正式上架還需要設定 AdMob 隱私訊息、付款與應用程式驗證，並在 Google Play 申報含廣告及實際資料處理方式。Android 正式簽章須使用自己的本機 `android/key.properties` 與既有上傳金鑰；這些私人檔案不在 GitHub。`assets/privacy-policy.txt` 已隨遊戲提供離線政策。

以下歷史說明中 `../../Builds/` 與外層 `output/` 指原開發工作區的交付資料；本次依要求僅上傳 Flutter 專案。APK/AAB、外部上架素材及相關本機路徑不包含在此倉庫，部分素材重建工具需要另行提供原工作區素材。一般 Flutter 執行與測試使用的資源已全部包含。

原生 Flutter 2D 遊戲，版本 `1.8.0+12`，使用 Flame `1.38.2`。

1.8.0 加入 AdMob 自選獎勵式廣告。營地保留免費補給，新增「廣告 +12」；先確認再播放，只在 earned-reward 回呼發放一次並立即存檔。廣告、隱私頁面與確認視窗的暫停來源分開記錄，回到前景不會提早恢復遊戲或音樂。開始畫面及遊戲右上方提供離線隱私政策與適用的 UMP 隱私選擇入口。

現階段依使用者選擇採兒童適用、G 級、非個人化廣告，移除 AD_ID 權限；預設一律使用 Google 官方測試 ID，不會產生收益。正式廣告需提供自己的 App ID 與 rewarded ID，並在 AdMob 完成訊息及帳戶設定。使用 `tool/build_admob_release.ps1 -ConfigPath config/admob.production.json` 建置，範本為 `config/admob.production.example.json`。Gradle 會拒絕缺少正式設定的 release，測試用最佳化 APK 須額外明確指定 `--dart-define=ADMOB_ALLOW_TEST_RELEASE=true`。說明見 `../../Builds/GooglePlay/AdMob-設定說明.md`。

`tool/export_privacy_text.py` 將 `../../Builds/GooglePlay/privacy-policy.html` 的實際政策內容同步為 `assets/privacy-policy.txt`，供遊戲離線閱讀。廣告 SDK 不獲得本機進度作為自訂識別碼；正式模式先透過 UMP 確認允許，再初始化及請求廣告。官方測試 App ID 無自己的 UMP 訊息，因此測試模式不能替代正式同意表單驗收。新增測試涵蓋 consent gate、重複獎勵、無填補、重試、晚到回呼、隱私選擇變更、生命週期及實際營地確認流程。

首次 Google Play 上架 AAB：`../../Builds/Android/forest-star-1.7.1-play.aab`，使用獨立的正式 upload key。私人金鑰與密碼保存在本機 `C:/Users/user/.android/forest-star-upload/`，請安全備份；`android/key.properties` 已排除版本控制。Release 建置缺少金鑰會明確失敗，不會再回退到 debug 簽章。既有側載測試 APK 的 debug 簽章不變，不能直接覆蓋正式商店版。

原交付的 1.7.1 AAB 未整合廣告，本次不覆寫它。新版須以上述正式廣告設定建置，再用 `tool/prepare_play_bundle.py` 輸出新的版本檔名，並重新驗證簽章、Google bundletool 及 16 KB 相容性。交付目錄包含公開上傳憑證、SHA-256 與原版 `Google-Play-上架說明.md`；新版接入及發布步驟以 `AdMob-設定說明.md` 為準，目前尚未提交 Play Console。

1.7.1 讓目前編隊的四位守衛以 33–36 邏輯像素的小角色在營地空地散步，有腳步起伏、轉身、停頓、待機呼吸與腳下陰影。`lib/camp_patrol.dart` 直接讀取四格編隊，換隊自動更新；空位不顯示，沒有額外解鎖夥伴。角色使用既有透明素材，四條閉合路徑避開建築、入口文字及底部資訊，不攔截地點觸控。離開營地、切到背景或成長彈窗出現時停止散步，返回原地接續。

`FOREST_PATROL_CAPTURE=1` 執行 `flutter test test/camp_patrol_test.dart` 可擷取 16 秒真實 Flame 畫面；`python tool/export_camp_patrol.py` 輸出完整營地與散步近景 GIF 至 `output/preview/camp-patrol-v1/`。

1.7.0 優化互動動畫：按鈕、導覽、夥伴卡片和營地地點按下會壓縮回彈，切頁以 240ms 淡入呈現，不移動觸控目標。選中夥伴有招呼動作；彈珠瞄準時軌跡加亮、發射器回彈、球體旋轉，擊破顯示得分浮字，獎勵沿曲線飛入資源列。守衛夥伴出手前微微蓄力、出手伸展、敵人行走擺動及受擊壓縮光圈，波次提示與耐久受損回饋獨立呈現。結算卡片彈入，提示訊息移到上方，避免遮住發射或編隊按鈕；切頁清除上一頁的提示。

`lib/interaction_motion.dart` 將表現用時鐘與物理規則分開，浮字／觸控回饋最多 20 組並自動回收。按下與放開需屬於同一控制項，拖離或取消不執行動作；切到背景會取消按壓，回來後的舊觸控不能觸發。成長彈窗真正暫停彈珠與戰鬥，動畫與恢復使用 120Hz 固定步進，避免不同刷新率產生不同戰況。

可用 `$env:FOREST_INTERACTION_CAPTURE='1'; flutter test test/interaction_capture_test.dart` 擷取真實按壓、拖曳瞄準、得分及四路戰鬥；`python tool/export_interaction_preview.py` 輸出三段 GIF 至 `output/preview/interaction-v1/`。這次沿用既有透明插畫，以原生 Flutter／Flame 動畫加強互動。

1.6.0 將守衛戰改為四路橫向防線：四位夥伴由上至下站在左側，向右攻擊右方來襲的怪物。四路共用固定步進，保留緩速、範圍傷害、連鎖攻擊及龜夥伴耐久加成。夥伴小屋可安排第 1–4 路；舊三位編隊保留原順序，第四格補入已解鎖且未上陣的夥伴，否則保留空位。未解鎖夥伴不能上陣。

底部四個導覽改用 APIXGo `gpt-image-2.5-flare` 生成的透明繪本插畫：木製彈珠座、兔狐夥伴、星光盾牌與提燈帳篷。搭配奶油色底座、金邊浮起選中卡片、綠色文字標籤與輕微浮動。插畫與文字分開繪製，沿用每格 120 邏輯像素的觸控範圍和等比例安全畫面。營地繼續以全屏地點動畫進入各頁。

導航原圖與完整提示詞位於 `output/imagegen/navigation-v1/`，執行 `python tool/prepare_navigation.py` 可保留原始透明邊緣拆成四枚素材。四路背景原圖及提示詞位於 `output/imagegen/guard-horizontal-v1/`，執行 `python tool/prepare_horizontal_guard.py` 可將道路中心對齊實際角色、彈道與怪物座標。畫面與 GIF 位於 `output/preview/navigation-v1/`。

1.5.0 加入營地原創背景曲《螢光小夜曲》：D 大調、6/8 拍、84 BPM、32 小節，約 68.57 秒，豎琴、音樂盒、長笛與柔和弦樂四聲部。`assets/audio/forest_camp.mid` 為標準 Type 1 MIDI；Android 直接使用系統 MIDI 合成器播放並循環，其他平台或 MIDI 初始化失敗時使用相同音符譜渲染的 `forest_camp.wav`。離開營地切回原冒險背景音，回營地切回主題；靜音、背景暫停及恢復沿用原有控制。系統 MIDI 音色可能隨裝置而異。

執行 `python tool/compose_camp_music.py` 可重建 MIDI 與音訊；不使用下載歌曲、錄音取樣或外部音色庫。MIDI 原檔、完整音訊、22 秒試聽及編曲／音量分析資料位於 `output/audio/camp-v1/`。Android 格式依據：[官方支援的媒體格式](https://developer.android.com/media/platform/supported-formats)。

1.4.1 將面板與按鈕上的雙葉裝飾替換成 APIXGo `gpt-image-2.5-flare` 生成的同畫風外框：奶油紙面、苔綠主按鈕、香檳次按鈕與金色選中卡片。保留透明圓角、金色木紋邊框，用九宮格方式拉伸中間及直邊，避免不同尺寸壓扁框角。套用於資源列、標題、夥伴卡片、資料框、營地資訊、導航、結算及進化繼續按鈕。原圖與完整提示詞位於 `output/imagegen/frames-v1/`，可執行 `python tool/prepare_frames.py` 重建四張素材。

1.4.0 加入彩珠育成：綠葉、藍水、紫星彩珠分別需要 1、2、3 次碰撞，擊破得到 6、14、24 成長分。金色珠為發射球。下方六個籃由左至右對應芽耳兔、泡泡獺、燈尾狐、苔石龜、星絨雀、月眠貓，進入籃口後以物理隔板限制在該籃內，落定時將本次累積分數及 8 分落籃獎勵一次計入該夥伴，另外給 8 星糖及 1 星露。

成長分按夥伴分開存檔，升級需求為 `24 + 當前等級 × 12`，餘額保留；未結識的夥伴可累積 40 分解鎖，Lv.3 / Lv.6 自動進化。舊版星糖升級／星露進化仍可使用。沿用 `forest_star_v1` 存檔，缺少成長分的舊存檔預設六位均為零，不改寫既有等級與進化。

`lib/growth_showcase.dart` 以透視矩陣、立體旋轉、角色放大彈出、光環、皇冠與前後景粒子呈現升級／進化；使用透明 2D 角色呈現 3D 感。粒子最多 100 顆、由時間解析計算，不累積物件，動畫期間阻擋底層操作、背景暫停，可按繼續或自動結束。彈珠素材由 APIXGo `gpt-image-2.5-flare` 生成，原圖與完整提示詞位於 `output/imagegen/marbles-v1/`，`python tool/prepare_marbles.py` 保留原始 alpha 拆成四張透明 PNG。

1.3.0 加入 Flame 粒子特效：彈珠命中火花、獎勵星光、角色命中的火星／水泡／綠色粒子，以及營地微風落葉、夥伴小屋光點、守衛細雨。特效裁切在場景內，切頁即清除、背景暫停，最多同時 18 組短暫粒子並自動回收。

1.2.1 修正彈珠台背景尺寸：從原始插畫保留完整木框，分區縮放中央底圖、框邊及中央銅釘，輸出與遊玩區相同比例的 872×908 素材，畫面使用完整顯示而非放大裁切。可用 `python tool/prepare_pinball_board.py` 重建。

- `lib/forest_flame_game.dart`：Flame 更新、場景元件、地點動畫和觸控分派。背景鋪滿畫面，角色、地點、UI 和觸控範圍共用等比例的安全座標，避免平板裁切或手機拉伸。
- `lib/game_session.dart`：遊戲規則與存檔，物理固定每秒 120 步；背景暫停、恢復時限制補算，取消拖曳不會發射。
- `lib/storybook_ui.dart`：場景與 HUD 繪圖、文字排版快取。動畫不會逐幀重建 Flutter 頁面。
- `lib/forest_effects.dart`：Flame ParticleSystemComponent 與加速度粒子、場景風雨繪製，跟隨遊玩區等比例縮放。
- `assets/storybook/character-0.png` 至 `character-5.png`：保留原始角色圖透明通道，重新依實際輪廓拆圖，包含完整腳部、耳朵和尾巴。

角色素材可透過 `python tool/extract_characters.py` 從原始圖集重建。這個步驟只保留、整理既有透明度，不重新生圖。

驗證與建置：

```powershell
flutter test
flutter analyze --no-fatal-infos
flutter build apk --release
$env:FOREST_UI_CAPTURE='flame'
flutter test test/ui_capture_test.dart
python tool/export_ui_gifs.py --captures output/review/flame --output output/preview/flame-v3
```

測試包含四種手機／平板比例、地點點擊、拖曳釋放／取消、多指干擾、生命週期、存檔，以及 60／90／120 Hz 更新下的固定步進一致性。這些是操作與模擬結果測試，不代表實機效能量測。

APK 位於 `../../Builds/Android/forest-star-1.7.1-camp-guards.apk`，Android 7.0（API 24）以上；目前沿用開發用簽章供側載測試。新版外框截圖位於 `output/preview/frames-v1/`。育成 GIF 位於 `output/preview/growth-v1/`。可用 `$env:FOREST_GROWTH_CAPTURE='1'; flutter test test/growth_showcase_test.dart` 重現真正落籃後的進化動畫；測試使用接近升級的測試存檔，不影響正式初始狀態。
