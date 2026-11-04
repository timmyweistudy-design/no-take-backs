唯讀靜態複查，未跑引擎、未改檔。

首輪原報情境：#1～#7、#9、#10 已修；#8 僅部分修復。依據：battle_sim.gd:1768、battle_code.gd:89、free_place.gd:347／452／502、game_modes.gd:42／167／127、game_result.gd:57、replay_view.gd:590。

必改 4 條：

1. **#8 未完**：規則碼仍漏 map_mode／bans／ai_style；另存大廳記憶無法涵蓋自訂預設及代碼往返。ruleset.gd:350、lobby_view.gd:117。
2. **禁牌覆寫紅方卡池**：兩邊名單不同時，一次禁牌便把紅方整池換成藍方剩牌，破壞原設定。應分別處理雙方卡池。game_modes.gd:188／192。
3. **雙人全場挑戰碼**：未擋 FULL_DUEL 就轉 VS_AI；玩家仍可全場部署，卻沒有敵兵距離禁區，可與朋友陣型重疊。應拒收或完整轉換。game_modes.gd:100、game_core.gd:54。
4. **輪替產生無效規則**：熔岩開噴口後換圖仍保留 vents；非熔岩結果輸出的對戰碼會遭拒收。換圖須清除不適用選項。game_result.gd:326、ruleset.gd:261。

試煉結果按鈕、禁牌跳過、獎勵 Esc 可返回續選，未見卡死；map_mode 重播及快轉均沿用 battle_rules（battle_view.gd:471、replay_view.gd:97）。

結論：有條件
