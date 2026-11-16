你是《落子無悔》(Godot 4.6.2) 1.6.0 實作的程式審查（B15 第 1 輪，最多三輪）。只讀。專案根目錄＝目前資料夾。
計畫 coordination/v1600-impl/b15-plan.md；差異 coordination/v1600-impl/b15-r1/diff.patch（快照 build/cg/b15/game，基準＝現在的 game/；game/ 另有 B12/B14 未提交改動，不在本批）。
重點：新 `scripts/game/lesson.gd`、`replay_view.gd` 棋課本、`save.gd` sanitize、測試 `test_lesson_v1600`。
請找：錯誤、S5 八種失敗邊界有沒有漏（版本不符、壞筆、取消、重啟、過期重算、容量滿、重複保存、寫檔失敗）、正式副作用（統計、進度、成就、紀錄、日誌）、還原是否真的 20/20（含軍令 NTB7、地圖規則、全場陣型、試玩版兵種）、`_ls_watch` 走看代碼路徑會不會留下覆盤狀態、背景執行緒收尾（離開、換頁、戰鬥中）、存檔驗型（JSON 浮點、超大字串、id 碰撞）、手把與 R14。附行號。最多 6 條、400 字內。最後一行「結論：可／有條件／不可」。
