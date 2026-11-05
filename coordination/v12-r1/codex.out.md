僅靜態審查；未改檔、未開遊戲。以下路徑相對於 `game/scripts/`，依嚴重度排序。

1. **試玩紀錄無法還原技能戰**｜`ui/screens/game_core.gd:213` 呼叫 encode 未傳施放紀錄；`game/battle_code.gd:16` 預設為空陣列｜玩家提供的試玩代碼會播成雙方都沒放技能，勝負可能不同｜傳入該場 `sim.cmd_log`，評分紀錄也使用同一份。

2. **覆盤原場基準漏掉全部技能**｜`ui/replay_view.gd:320` 未傳 last_cmds；`:469` 仍啟用 scripted，`:488` 的修改場卻有傳｜即使完全不改陣型，原場與重算也可能不同，誤導玩家判斷｜基準呼叫一併傳 last_cmds。

3. **技能規則被判為預設相同**｜`core/ruleset.gd:366、399` 的相等比較未含技能；`ui/lobby_view.gd:86` 依此決定是否改成 custom｜標準規則開技能後仍亮標準卡片，錯誤名稱再由 `:123` 存入 last_rules｜equals 額外比較技能欄位；勿直接改動舊版 key_fields 的編碼長度。

4. **護盾吸收仍全額計入承傷**｜`core/battle_sim.gd:726、759` 先累加 dmg_taken，`:799` 才扣護盾；`ui/screens/game_core.gd:227` 直接拿來報表｜例如護盾完全吸收 90 傷害，血量未減，承傷仍增加 90｜技能局區分護盾吸收與實際承傷；保留關技能時原統計與雜湊行為。

5. **困難 AI 評估漏算技能**｜`core/hard_ai.gd:50` 建模後直接 run_to_end；`core/battle_sim.gd:141` 預設雙方 cmd_auto=false，實戰則由 `ui/battle_view.gd:322` 開紅方 AI｜第二局起挑選反制陣型時，評估的是紅方完全不施法的戰況｜候選模擬設定與實戰一致的紅方施法策略，明確固定藍方假設。

結論：不可
