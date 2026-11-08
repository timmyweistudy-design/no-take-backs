唯讀靜態審查完成；未改檔、未跑 Godot。以下引用檔名皆位於 `game/scripts/`。

**必修**

- **契約讀檔失效**：`game/save.gd:200` 的 `sanitize_run()` 重組欄位卻未保留 `contract`；重啟後 `ui/screens/game_core.gd:760` 一律讀成未簽，代價與報酬一起消失。
- **續局可能整份消失**：`game/save.gd:209` 仍限制累積金≤70、隻數加成≤14；契約獎勵疊加事件可突破，讀檔直接回 `{}`。
- **代價可繞過**：`ui/screens/game_modes.gd:447` 只降低預算／上限，沒有處理沿用的超額陣型；`ui/screens/game_place.gd:105` 開戰也未驗花費／人數。簽窮兵、寡兵後不動陣型即可照常打，贏了照領獎。
- **契約漏結算**：`ui/screens/game_result.gd:278` 只有第1～6站勝利能進 `_gauntlet_reward()`。輸局不顯示失敗，第7站勝利不發契約獎勵；應在正式戰鬥結束時統一結算。
- **淡圈污染原局**：`ui/replay_view.gd:210` 返回時未清 `tm_ghost`，`ui/screens/game_result.gd:39` 播完也未清；`ui/battle/battle_units.gd:419` 僅檢查 `live`，結果頁仍符合，返回原局後會混入「如果」時間點的白圈。
- **分岔少一 tick**：`ui/replay_view.gd:487` 的交錯索引除2正確，但 `core/battle_sim.gd:292` 先加 tick，`:869` 才記戰力；首對樣本代表 tick 1，差異應回 `i / 2 + 1`，目前時間與標記提前0.05秒。
- **宿敵誤記／分身**：`ui/screens/game_core.gd:378` 用 `w != 0`，和局也算敵人打敗你；應限定 `w == 1`。再輸強化宿敵時又記強化後陣型（`game_modes.gd:904`），比對不到原紀錄，新增分身而非增加原宿敵敗績。
- **增援繞過兵種硬上限**：`ui/screens/game_modes.gd:952` 直接 append；例如已有2隻石巨像仍加第3隻，違反 `core/fantasy_defs.gd:39`。

**建議**

- `ui/replay_view.gd:628` 平常每 tick 多跑一份模擬，成本非零但非必然 bug；seek 後可能一次補跑整段，繞過既有10ms分批預算，應一併分批。
- `ui/screens/game_modes.gd:904` 陣列比較受單位順序影響；相同部署換排列會重複建檔，建議排序後比較。

**不用改**

- `_begin_battle` 清除、`_rv_play` 重建、倒退 seek 重建、暫停停止推進皆合理；淡圈壓扁、恢復鏡頭矩陣與隊色點畫法正確。按鈕三條件完整（`replay_view.gd:65`）。
- 契約有效編號的判定合理；前進／續局皆重建軍隊後扣一次，沒有累扣；`ct_pick` 有重設，獎勵後清契約避免同次重領（`game_modes.gd:399`）。
- 宿敵優先刪已復仇、否則刪最舊；種子與名單不變時續局一致。新增格在敵方10～15欄且避開佔格；復仇旗標與宿敵資料會保存。
- diff 未改核心模擬、數值或 FINGERPRINT 計算；未執行驗證指紋值。

結論：有可繞過契約代價、續局遺失及覆盤狀態污染等實際缺陷，修正後再提交。
