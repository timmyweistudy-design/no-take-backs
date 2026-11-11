唯讀靜態審查，未執行遊戲或測試。確認 4 條必改：

1. [game_screens.gd:421](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:421)：便條未處理 Esc／手把 B，會走 `_nav_back()`，沒有標記已讀。擺陣、結果頁下一幀又呼叫 `_boss_note()`，便條立即重開，返回鍵無法關閉。應為 `boss_note` 分支呼叫 `_close_boss_note()`，補測兩種返回輸入。

2. [lobby_view.gd:516](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/lobby_view.gd:516)：大廳以 `overlay="lobby"` 開啟，但 `_boss_note()` 在 overlay 非空時直接返回，首次大廳便條永遠不出現。應支援便條疊在大廳上，保存原 overlay，關閉時還原；不能直接清空而退回標題。

3. [game_screens.gd:56](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:56)：清檔只用 `begins_with(px)`；例如 `shot_en_150_` 也匹配 `shot_en_150_plain_`、`shot_en_150_pad_`。基礎組啟動可能刪掉另一組正在使用的存檔，破壞平行截圖的隔離與可重現性。應精確匹配該組的存檔名稱及其備份，或改用每組獨立目錄。

4. [game_screens.gd:900](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/game_screens.gd:900)：印章直接以 `int(tz("T") * sc)` 當字級，動畫途中產生大量表外字級，也會跨越 `_font_for()` 的字型門檻，造成蓋章時換字型。應固定使用 `tz("T")`，透過繪圖 transform 縮放整個印章，完成後還原。

結論：有條件