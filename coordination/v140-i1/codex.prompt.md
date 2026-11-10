你是資深 Godot 4.6 工程師兼遊戲設計師。唯讀：不要改檔、不要跑 Godot。
《落子無悔》（game/）V1.4.0 方案 docs/history/2026-11-08-v1.4.0-plan.md。第一批三項（#1 時光機、#3 戰利品契約、#2 宿敵戰記）未提交 diff：coordination/v140-i1/diff.patch（或讀 game/ 現檔）。
請找真的 bug（繁中、1300 字內，引用 檔案:行）：
#1：diverge_tick 與 power_log2 的格式（兩隊交錯）是否正確；tm_ghost 生命週期（_begin_battle 清掉、_rv_play 設定、seek 往回重建、暫停、離開覆盤、看完回結果頁）；_tm_sync 每 tick 呼叫的成本；淡圈畫法；時光機按鈕條件（只有對 AI、有 last_armies、非觀戰）。
#3：契約判定 contract_ok、代價在 _gauntlet_next／續局時套用一次且不重複、存檔欄位、ct_pick 在不同站之間的殘留、獎勵是否被重複發放。
#2：宿敵紀錄時機（只在正式遠征輸）、去重比較、上限刪除策略、_nemesis_for_stage 種子與續局一致、_nemesis_army 多帶一隻最貴兵的格子是否合法（格子在敵方部署區？與既有單位重疊？）、打贏判定復仇、存檔。
另：有沒有改到模擬或 FINGERPRINT（不該有）。分「必修／建議／不用改」。最後一行「結論：…」。
