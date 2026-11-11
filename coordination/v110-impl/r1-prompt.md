《落子無悔》1.1.0 實作審查第 1 輪。你是工程審查。不要改檔，只讀。
方案 docs/2026-11-11-v1.1.0-plan.md；實作裁決 coordination/v110-impl/ledger.md；差異 coordination/v110-impl/r1-diff.patch（也可直接讀 game/）。
重點：
1. H1 覆盤重算與 GIF 取消（replay_view.gd rv_ctl／rv_old／_rv_poll／_rv_exit、gif.gd ctl、battle_view.gd _exit_tree）：競態、離開條件（overlay != "review" 是否正確）、回收、結果作廢。
2. H5 小地圖頭頂空間（ui_base.gd _fld_xf）：點擊、自由部署、重播、圖鑑小劇場、版面截圖是否一致。
3. N4 每日練習（game_modes.gd daily_practice／_start_daily_day、game_result.gd 重置、game_v16.gd _daily_entry／_draw_daily_past／_daily_finish）：練習會不會寫到 daily_best、連勝、daily_pend、分享格、成就、eff_games；「再來一次」是否保留練習旗標。
4. N5 最佳解碼（solution_code.gd、game_core.gd _best_sol_record、game_menus.gd _accept_solution、save.gd sol_entry_ok）：驗證、試玩版、固定兵、重打機制重用的副作用。
5. 其他：Q1 長按清空（game_screens.gd _pad_x_hold／_pad_clear_tick）、B13 詞彙格（game_v16.gd nb_words）、A13 lock_groups、A15 ACH_CAT、A21 lb_drop、N1 回報分類與 A24、E2 platform_report、E3 掌機預設與 _settings_row_y、check.py serial marker 與 t_stateful3 拆分（兩行程是否互踩檔案）、v161_metrics 改動。
每條給 檔名:行號、重現情境、建議改法。最多 10 條必改；其餘建議另列。不得碰 FINGERPRINT。
繁體中文，2000 字以內。最後一行：結論：可／有條件／不可。
