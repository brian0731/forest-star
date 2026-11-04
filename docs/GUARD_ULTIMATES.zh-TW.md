# 守衛四路大招

守衛畫面下方有四個獨立大招按鈕。每場戰鬥，每路可施放一次；下一場開始才補回次數。空路線、戰鬥未開始、已使用、沒有存活敵人時均不會消耗次數。

施法動畫長 3.35 秒，在第 1.25 秒爆發並結算傷害。動畫期間暫停敵人移動、普通攻擊、出怪及波次計時，同時鎖定操作；切到 App 背景會連施法動畫一起暫停。結束後自動恢復戰鬥，不需額外點擊。

依上陣夥伴決定魔法，傷害基準使用該夥伴開戰時的攻擊力：

- 森羅風暴：本路 7 倍、其他路 3 倍，擊退全場存活敵人 28 距離單位，上限為出生點。
- 蒼海星潮：本路 6 倍、其他路 3 倍，讓全場敵人獲得 4 秒緩速。
- 焰星隕落：本路 9 倍、其他路 4 倍。
- 大地聖盾：本路 5 倍、其他路 2.5 倍，回復營地最大耐久的 25%，不超過上限。
- 雷霆星陣：本路 8 倍、其他路 4.5 倍，擊退全場敵人。
- 月華審判：本路 10 倍、其他路 3.5 倍。

守護型夥伴使用大地聖盾；其餘優先依草／水／火屬性配招，沒有這三種屬性的連鎖／重擊夥伴分別使用雷霆星陣／月華審判。大招擊殺沿用原有計數、波次及勝利獎勵流程，不會額外發放第二份獎勵。

## 畫面與音效

使用現有 Flame 框架，在 2D 畫布以透視投影、角色姿態矩陣、粒子深度排序、光束、衝擊波及傾斜魔法陣呈現立體感。六種魔法分別有風暴葉片、水泡、隕星、盾牌碎晶、雷光及月輪。背景覆蓋整個實際螢幕，包括安全區及平板邊緣；施法時隱藏上層教學／轉珠／隱私按鈕。

動畫中的粒子數量有上限。系統啟用「減少動畫」時會減少粒子、快速旋轉及震動，不改變傷害時點。施法與爆發音效由 `tool/generate_magic_audio.py` 原創合成，無外部音效素材。

主要程式：`lib/ultimate_spell.dart`、`lib/ultimate_showcase.dart`；戰鬥邏輯在 `Combat.reserveUltimate` / `resolveUltimate`，流程與輸入鎖定在 `GameSession.castUltimate`。

## 測試與預覽

```powershell
flutter test test/ultimate_test.dart test/ultimate_showcase_test.dart
$env:FOREST_ULTIMATE_CAPTURE = '1'
flutter test test/ultimate_showcase_test.dart
Remove-Item Env:FOREST_ULTIMATE_CAPTURE
python tool/export_ultimate_preview.py
```

預覽來自 Flutter 測試實際渲染的遊戲畫面：

- `output/preview/ultimate-v1/six-spells-demo.mp4`：六種魔法及施法音效示範。
- `output/preview/ultimate-v1/fire-ultimate.gif`：火系大招動畫。
- `output/preview/ultimate-v1/six-spells.jpg`：六種魔法畫面總覽。
- `output/review/ultimate-v1/battle-ready.png`：四路按鈕配置。

測試涵蓋每路限用一次、無效操作不扣次數、命中時點、六種實際效果、擊殺及獎勵不重複、背景暫停、動畫完結恢復，以及手機／直向和橫向平板的全屏覆蓋。本次不產生 APK，也不執行 iOS GitHub Actions。
