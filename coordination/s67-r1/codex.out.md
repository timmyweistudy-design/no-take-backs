唯讀審查 HEAD，發現 5 點；以記憶體測試重現兩種報表假綠燈，未重跑 Godot 全套。

- **P1｜`game/scripts/game/sfx.gd:111`**：三軌匯入採 QOA 壓縮，`data.size()/2` 並非樣本數，約 14.5 秒的音樂會在約 3 秒處循環。建議於匯入設定啟用完整循環，或以長度×取樣率設定終點。[Godot 文件](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html#class-audiostreamwav-property-loop-end)

- **P2｜`game/scripts/ui/replay_view.gd:65`、`:97`**：最後時刻仍依賴播放歷史。先倒帶到觸發前會清掉 `clutch_tick`，再跳到觸發後便無法重建；直接首次跳過觸發點亦同。建議快轉時重新判定觸發點。`game/tests/run_tests.gd:1061` 刻意排除 clutch，且只用 `_sim_step()`，因此測不到此錯誤；補「觸發後→觸發前→觸發後」測試。

- **P1｜`game/tools/balance_report.py:92`**：完整性只驗檔名、筆數及場次鍵，未驗列內 `mode`、`rule`、`level`。把 4,800 筆訓練池資料改掛驗證池檔名，實測仍 exit 0、顯示全過；不同 AI 等級也可冒充。建議逐列比對 manifest，並記錄、驗證池種子或摘要。

- **P2｜`game/tools/balance_report.py:218`、`:233`**：驗證池全平手時，勝方剩餘中位數與碾壓率均回退為 0，實測仍全過；亦未檢查戰鬥秒數紅線。建議零決勝場不得宣告通過，並補秒數、平手率、逾時率及相應門檻。

- **P2｜`game/tools/balance_report.py:252`**：同規則不同 `@level` 的勝率與換手統計共用 summary 鍵，後者覆蓋前者，只有區間鍵含等級。建議所有相關鍵都納入 level，補多等級同批輸出的驗證。

`duel` 方向正確：紅方先鏡像回藍方表示，再由 duel 交換左右；音樂切狂熱、回標題會停三軌，音量變更由 `_process` 套用。未見 `watch_mode` 經回標題或新模式後殘留。

可否繼續：建議先修正上述問題並補回歸驗證，再進下一輪。