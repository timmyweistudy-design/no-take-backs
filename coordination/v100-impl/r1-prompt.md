《落子無悔》V1.0.0 實作審查第 1 輪。你是工程審查。不要改檔，只讀。
方案：docs/2026-11-10-v1.0.0-plan.md（§6 優先清單）。本輪實作的差異：coordination/v100-impl/r1-diff.patch（也可直接讀 game/ 下的檔案）。
重點檢查：
1. steam.gd 排行榜單一通道（_lb_q／_lb_cur／lb_tick／逾時／限額）與成就 _store／_on_stats_stored：亂序、遲到回呼、重入、限額計數、逾時後暫停、找榜失敗、下載回呼一定會回、存檔待送不丟。
2. 三考取消（game_v16.gd _trio_cancel／trio_old／TRIO_LIMIT_MS；v16_trio.gd results ctl；puzzles.gd play ctl）：執行緒回收、競態、逾時結果不寫紀錄、離場、_exit_tree。
3. workshop.gd SOLVE_MS、save.gd _quarantine、game_v16.gd _feedback（feedback_key／_write_text／_clip_set）。
4. 五牌入口（game_menus.gd home_plaques、hub_items、HUBS、hub_note；game_playroom.gd 刪 _draw_playroom；ui_base _nav_back）：返回、nav_hub、試玩版限制、seen、建議下一步（v16_guide.gd next_step、gauntlet_cont、puzzle_more、next_puzzle_id；game_v16 _ns_text、_pz_label）。
5. 重打保留擺法（game_core.gd retry_key／_mark_retry／_apply_retry；game_result.gd）：試煉順序、換關、固定兵、自由部署。
6. 其他：高倍速降噪（battle_fx FAST_SKIP）、遠征總結單人（_coop_settle、save.gd clog who）、同音效上限（sfx.gd）、教學提示、圖鑑範圍格網、export_check／自我檢查、CI 分層 yaml、dev_main --sil。
每條給 檔名:行號、重現情境、建議改法。最多 10 條必改；其餘建議另列。不得碰 FINGERPRINT（模擬不能動）。
繁體中文，2000 字以內。最後一行：結論：可／有條件／不可。
