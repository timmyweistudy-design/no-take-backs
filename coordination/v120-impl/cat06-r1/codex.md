只讀審查，發現 7 條必改。以下路徑相對於 `game/`。

1. `scripts/ui/battle/battle_units.gd:335、343`：凌晨 0～4 點被判成午；且每幀讀系統時間，跨時段時盤面突然變色。修正完整時段區間，並在開局固定晨昏值。

2. `scripts/ui/battle/battle_units.gd:381`：舊 `_draw_ambient()` 仍先畫雪／落葉，未受截圖、4 倍速、色盲限制；新函式提前返回也關不掉，冰圖還會超過 60 顆。合併兩套粒子並共用開關及上限。

3. `scripts/ui/battle/battle_units.gd:353`：天氣用地圖＋局數決定，動畫用全域 `time`；分享代碼會重設局數，重播或跳轉同一 tick 的天氣不同。改用可重建的對局識別值及播放 tick 推導。

4. `scripts/ui/battle/battle_units.gd:343`：色調畫在平原隊色區與兩條隊色界線之後（原繪製於 270～314 行），晨昏會改掉這些功能色。把隊色標記移到色調之後畫。

5. `tools/dev_main.gd:274`：只查 `clutch_t`，但橫幅 1.6 秒即消失，`slow_left` 壓暗持續 8 秒；剩餘慢動作仍被計入低對比。加入 `slow_left <= 0` 條件。

6. `scripts/ui/map_art.gd:368`：`grass` 分支永遠走不到；平原地形回傳 null，且 `_map_tex()` 明確跳過平原，新增草筆觸／野花完全不顯示。為平原建立獨立的靜態烘焙路徑，勿改模擬地形。

7. `scripts/ui/map_art.gd:365、386`：只允許 FREE 格，冰湖真正的冰面 FAST 格被跳過，裂紋只出現在普通地面。讓冰面細節適用 FAST，並保留原有快地形辨識標記。

結論：有條件