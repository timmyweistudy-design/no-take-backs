必改 4 項（只讀靜態審查，未執行測試）：

1. [game_place.gd:830](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd:830)：暗擺紅方按 L，呼叫的 `_load_checked` 在 534、544、554、563 行固定讀寫 `armies[0]`。結果會覆寫已確認的藍方，紅方沒有載入；自由模式 undo 卻記在紅方。應傳入目前軍隊，按其隊伍解碼、驗證及替換。

2. [game_place.gd:819](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_place.gd:819)：A、L 在成功前呼叫 `_fp_push_undo()`，會立即清空 redo，滿 40 筆還會丟最舊紀錄。A 失敗只移除新快照；L 失敗連快照也保留。工具未改陣卻破壞復原歷史。應先在副本驗證，成功且有變更才提交快照。

3. [keymap.gd:73](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/keymap.gd:73)：新增固定鍵 A、L、`[`、`]` 未保留，也未登記為可改動作。使用者可把其他動作綁到這些鍵，入口翻譯後原功能便無法觸發，例如將 flip 綁 A，自由模式就失去對齊鍵。應納入動作表，或保留固定鍵並處理既有綁定。

4. [coach.gd:127](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/game/coach.gd:127)：evidence 只每 64 tick 檢查取消／期限；短戰可能完全漏查，第一場中止後仍啟動第二場。第 201 行又把中止產生的空證據包成 `found`，逾時結果會被快取。應於每場前後檢查、首場失敗立即返回，並向 search 傳回 cancel／timeout。

其餘核對：預跑 Array 的同步取值、背景回收及丟棄路徑一致；書籤沿用 seek 防重入。棋譜本觀看沿用試玩版檢查，lambda 有捕捉逐筆值，刪除後每幀重畫。此 patch 未修改模擬及舊代碼編解碼實作。

結論：有條件