必改 5 項（只讀靜態審查，未執行測試）：

1. **P1 每日色調污染戰役與外部重播**：[battle_state.gd:208](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_state.gd:208)。`_camp_play` 先設 `challenge_army`，使 `_start_mode` 保留上一場 `daily_spec`；每日後進戰役會優先取清晨。`watch_code` 也未清每日／戰役旗標，觀看同一代碼可能因前場不同而變色。應明確建立本場模式上下文。

2. **P1 非平原漏套每日清晨**：[battle_units.gd:251](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/battle/battle_units.gd:251)。地形圖只在 `rules.time_of != 0` 才呼叫 `_tone()`；每日規則預設為 0，因此河谷等每日題完全略過新增色調。應統一套用流程。

3. **P1 舊測試必敗**：[battle_visual.gd:499](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/battle_visual.gd:499) 仍要求原始碼含 `Vector2i(14 * CELL, CELL)`；改成 15 格後此斷言必失敗，須同步更新。

4. **P2 低對比未實作 8% 警告**：[layout_check.sh:102](/mnt/c/Users/timmy/projects/no-take-backs/game/tools/layout_check.sh:102)。只列前三名，還排除少於十隻的戰鬥；沒有按每張截圖判斷超過 8%，不符合類別規劃。應逐張產生明確警告。

5. **P2 形狀測試沒有驗到產品行為**：[battle_visual.gd:813](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/battle_visual.gd:813)。直接自行傳 20／8 給 `_ell`，即使 `ring_base` 永遠畫圓也會通過。須驗實際底座與合成格，涵蓋換隊、色盲及 fan。

其餘靜態追查：隊伍傳遞與 fan 索引未見錯置；棉布與格線共用座標變換，新增一次快取貼圖繪製。純黑目前實際量的是 RGB≤8；轉場／暫停誤擋仍需固定截圖驗證。

結論：有條件
