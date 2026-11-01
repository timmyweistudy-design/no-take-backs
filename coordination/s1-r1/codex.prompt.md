# 程式輪 S1「可信」＋S2「混戰與手感」（Codex 唯讀，第 1 輪）

第三輪方案 docs/2026-11-01-optimization-plan-v3.md 的 S1 已實作。請看 `git diff f7f7c9c HEAD -- game/ .github/`（含 S2）；golden.json 是資料，不用逐行看。

- **A1**：ui_base.PLAY_EFFECTS（official／replay／review × series、progress、log）；_begin_battle 帶 kind；_replay 走 "replay"；_finish_battle 與 _pt_rate 依矩陣寫入。測試 test_play_effects 走正式畫面程式，重播 3 次存檔不變（改回會紅）。
- **A4**：core/events.gd 常數表；battle_sim 與 battle_view 改用常數；測試檢查每個送出的事件都已登記。
- **T1**：tools/check_all.sh（匯入錯誤、load_all.gd、--boot-check 正式入口、測試完成標記與 SCRIPT ERROR、鏡像、金標準、打轉、素材）；CI 兩平台改用。三種注入錯誤都會紅。
- **A2**：輸入命令佇列（_enqueue／_process_cmds）＋畫面世代 _gen／_btns_gen；從 _draw 移除派發。測試 8 組序列（拿掉世代檢查會紅）。
- **T2**：tools/golden.gd：1000 場金標準，每 100 tick 狀態雜湊，回報第一個分歧場次與 tick；測試加「fast 與正式逐 tick 狀態與事件一致」「陣型順序打亂指紋不變」。改擊退邏輯時在第 0 場 tick 100 抓到分歧。Windows 版 Godot 也跑了完整 1000 場。
- **T3**：main._run_perf 改成真的 48 隻（量測專用 160 金）、整場、4 倍展示速度到狂熱、啟動與色盲重建時間、p99、硬體資訊。結果在 docs/perf/s1-baseline.json：整幀 p95 9.6ms、p99 10.9ms（RTX 3060 筆電，不是最低規格）。

另外 S2（battle_view.gd、art.gd）：跳字合併與排版 _merge_text／_layout_texts／text_overlap_stats、特效預算 _add_fx、最後時刻 _draw_clutch_banner／_clutch_dim／_focus_dim／_draw_vignette、擁擠光圈、受擊後退 hurt_dir、揮擊殘影、戰力條狀態、Art.pose 新參數。金標準已加寬雜湊（潛行、衝鋒、減速、冷卻、面向、導航）並重產。測試 98/98；新測試 test_crowd_readability 逐幀量 6 場（拿掉排版會紅）。

請找：正確性 bug、假綠燈、遺漏的路徑。特別看：
- 輸入佇列下，塗兵、拖曳等直接處理的滑鼠路徑和佇列的交互
- 手把搖桿連發
- 截圖／影片模式有沒有被佇列影響
- check_all 在 Windows 的 bash 是否可行
- 金標準的雜湊涵蓋夠不夠（stealth、charge、slow、cd 沒進 state_sig）
- 量測用「replay」會不會影響其他狀態
- S2：排版每幀 O(n²) 的成本、合併用格子邊界的抖動、關鍵跳字超過上限時的行為、受擊後退與展示緩衝的時序、測試是否真的量到最終畫面

繁體中文、≤1,200 字，每點附檔名:行號與建議修法，最後一句給「可否繼續」。
