你是《落子無悔》(Godot 4.6.2) 1.6.0 實作的程式審查（第 1 輪，最多三輪）。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
B09：規劃 coordination/v1600-impl/b09-plan.md；量測 coordination/v1600-impl/b09-abba.txt（腳本 b09-abba.sh）；方案 docs/2026-11-15-v1.6.0-plan.md §4 B09、S7（coordination/v1600p/r3-codex.md）；差異 coordination/v1600-impl/b09-r1/diff.patch。
重點：①錯命中：包會不會在不該用的時候被用（特殊塗裝、色盲切換中、塗裝改到一半、build 世代交錯、匯出版來源雜湊跳過的條件、清冊和檔案不一致、`_state` 靜態快取在換塗裝後不重查）；②`_baked`／`_assemble` 的 await 與世代檢查（拼頁在背景時 build 又重來）、WorkerThreadPool 任務取消／洩漏、load_threaded_request 同一路徑重複請求；③壞包退回：fail 後正在進行的其他讀取怎麼辦、`pack_stats`；④TYPES_PER_PAGE 6→2 對淘汰邏輯（`pages.size() >= MAX_PAGES` 丟第一頁新兵、null 槽）與記憶體；⑤量測是否可信（`--bench-blank` 把畫面關掉只量烘焙——冷熱各 20、ABBA 的設計、開機頭兩幀不計是否合理；有畫面時向量替代畫法的長幀沒算進來，該不該算）；⑥測試能不能真的抓到解碼差與過期包。
附行號。最多 6 條必改、500 字內。最後一行「結論：可／有條件／不可」。
