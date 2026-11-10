《落子無悔》V1.0.0 實作審查第 2 輪。你是工程審查。不要改檔，只讀。
你第 1 輪的意見在 coordination/v100-impl/r1-codex.md；處理結果見 coordination/v100-impl/ledger.md「實作審查第 1 輪」。修正在最新 commit（git show HEAD）。
1. 逐條核對第 1 輪 10 條與其餘建議：已修／部分修／未修，給檔名:行號。
2. 修正本身有沒有引入新問題（特別是 steam.gd 的 _lb_stale／_lb_eat_stale、成就 ach_dirty／_ach_inflight／_ach_resend_after、game_modes.gd 的 ws_thread／_ws_jobs／_accept_workshop_done、puzzles.gd _stopped、save.gd quarantine 失敗路徑、v16_guide.gd ai_count、CI yaml 的 export-windows 與 export_check.sh 的 wp／linux_tpl）。
3. 最多 6 條必改（檔名:行號、重現、改法）。
繁體中文，1500 字以內。最後一行：結論：可／有條件／不可。
