必改 6 項（靜態審查，未執行測試）：

1. **手把無法翻牌**：[game_place.gd:1229](game/scripts/ui/screens/game_place.gd#L1229) 只登記按鈕；擺陣方向鍵移游標、A 落子，自由模式也攔走十字鍵與 A，沒有移焦點／啟動翻牌的路徑。工具「更多」同樣無法用手把開啟。

2. **漏搬「最近愛用」**：[game_v16.gd:1444](game/scripts/ui/screens/game_v16.gd#L1444) 原有普通難度的 `ps_fav`；新紙卡畫完開場白便結束（[game_place.gd:1288](game/scripts/ui/screens/game_place.gd#L1288)），須補回。

3. **掛牌座標錯位**：[game_place.gd:325](game/scripts/ui/screens/game_place.gd#L325) 保存未縮放敵區，HUD 直接使用；非標準尺寸經 `_cam` 縮放置中後，翻牌位置、紙卡寬度均不對應敵區，可能侵入我方部署區。須轉成螢幕座標再排版。

4. **紙卡會點穿**：[game_place.gd:1275](game/scripts/ui/screens/game_place.gd#L1275) 只畫背景，沒有攔截輸入；配合上述錯位，點紙卡可操作底下部署區。須攔住按下、拖曳、放開及右鍵。

5. **按鈕契約不一致**：[game_place.gd:1229](game/scripts/ui/screens/game_place.gd#L1229) 固定啟用，略過 `_btn` 的停用截圖狀態、hover 登記及加強焦點框；應共用按鈕處理。

6. **測試不足**：[ui.gd:2449](game/tests/suites/ui.gd#L2449) 多為字串搜尋與人工按鈕陣列。須補真實輸入、縮放遮擋，以及各擺陣變體實際 `click_count()`／R14 檢查。

結論：不可
