只讀靜態審查；未執行會寫入存檔的測試。必改：

1. **P1 每日狀態污染**：[game_v16.gd:2523](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd:2523) 先設 challenge_army，使 _start_mode 保留舊 daily_spec／daily_practice。每日練習後進塔會跳過塔結算；正式每日後進塔，塔勝場可能更新每日紀錄及上傳榜單。入口須明確清除兩者。

2. **P1 覆盤可跳層**：[game_result.gd:387](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_result.gd:387) 未限制 official，按目前 sim.winner 顯示下一層。正式輸掉後，覆盤改陣贏了仍可爬樓；應依正式結算狀態提供按鈕。

3. **P2 續局未持久化**：[game_v16.gd:2528](/mnt/c/Users/timmy/projects/no-take-backs/game/scripts/ui/screens/game_v16.gd:2528) 只改記憶體，回標題也只重試失敗寫入。未完賽退出程式會遺失起始層；亦未保存 §11.11 要求的陣型。須保存並還原續局資料。

4. **P2 測試不足**：[modes.gd:1605](/mnt/c/Users/timmy/projects/no-take-backs/game/tests/suites/modes.gd:1605) 僅驗純函式；須補上述流程、重啟續局、平手、模式切換及讓子代碼往返／舊場 golden 回歸。

未見修改模擬或舊序列化；讓子沿用自訂戰績、成就及 _record_match。塔固定單局，平手目前結束爬塔；試玩鎖、驗型、清除鍵及有界回退遞迴未見阻擋問題。

結論：不可
