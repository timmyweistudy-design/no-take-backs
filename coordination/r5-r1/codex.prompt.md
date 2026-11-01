# 程式輪 R5（Codex 唯讀，第 1 輪）

請看 `git diff fc29ed3 b484147 -- game/`。

- scripts/ui/view_buffer.gd：展示緩衝。模擬領先畫面 DELAY=2 tick；每 tick 存快照（VUnit 欄位、事件、背水、狂熱、戰力、存活數、finished）。pump() 補到 2 份，advance() 播最舊一份。
- battle_view.gd：_sim_step 先 pump、advance、再 pump；新進緩衝的攻擊事件記 atk_hit[src]=命中 tick；繪圖用 atk_progress(展示 tick −(命中 −2), 兵種) 得到三段式進度（前搖固定 2 tick、揮擊與後搖依攻擊間隔壓縮）。HUD、最後時刻判定、鏡頭框選、事件演出全部改讀 view。結果畫面勝方跳躍。
- art.gd：pose()、unit_xf()、overlay()（M_HURT／SPARKLE／BROWS／HOOD／BRACE）；_infantry／_cavalry 的武器改吃 w（−1～+1）。sprite_cache 攻擊 8 格，表情不烘焙，用 overlay 疊。
- codex.gd：×5/2 → ×2.5。
- 測試新增 test_ui_consumers：用 game_screens.gd.new()＋假音效替身，把 6 場真實戰鬥逐 tick 交給 _sim_step（含 _on_event），檢查不報錯、每個攻擊 tick 都有 fx、緩衝排空；命中前一格已在前搖；圖鑑 _codex_tick 每段都跳字。已證明拔掉演出或跳字會紅。

Claude 已驗證：測試 73/73、截圖（docs/shots-r5/13_poses.png 動作表情樣品）、效能 draw p50 1.8ms。

請找：展示緩衝的正確性（重播、跳過、慢動作、頓格、截圖／影片模式、結果畫面是否都讀到完整播完的狀態；finished 的時機；prev_pos 插值跨 advance 是否跳格）、atk_progress 的邊界（攻擊間隔 < 4 tick、狂熱／背水加速、同一隻連續命中覆蓋 atk_hit）、overlay 與貼圖座標對齊、測試假綠燈、任何會影響確定性的地方（應該沒有：模擬不讀畫面）。
繁體中文、≤1,500 字，每點附檔名:行號與建議修法，最後一句給「可否繼續」。
