唯讀審查，不要改檔、不要開遊戲視窗、不要跑 --steam-test。《落子無悔》第十三輪實作中：殘局擴到 10 章 100 關、試煉 30 關。方案 docs/2026-11-06-puzzle-expansion-plan-v13.md，裁決 coordination/v13-ledger.md。關卡內容還在量產，這次只審程式（git diff 看未提交改動）：
- game/scripts/game/puzzles.gd（章節、rules_of、cmd_log、outcome、play、check_extra、best_lineup）
- game/scripts/core/army.gd（格子部署擋牆）
- game/scripts/ui/ui_base.gd、battle_view.gd、battle/battle_units.gd、screens/game_core.gd、game_place.gd、game_result.gd、game_menus.gd、game_modes.gd（殘局規則、技能時間面板、目標標記、三層提示、章節清單、試煉 30 關與固定敵陣、成就）
- game/tools/balance/puzzle_forge.gd、trial_forge.gd、tests/suites/content.gd、modes.gd、save.gd、tools/dev_main.gd 的 _shots_v13
重點找「會讓玩家碰到」的錯：判定和畫面不一致、重播／覆盤／對戰代碼遇到殘局規則（地形、撐住、技能紀錄）會不會壞、舊 25 關與舊場次指紋會不會被動到、存檔、試玩版範圍、手把操作、提示揭曉後狀態、時序關的 plan 與冷卻、試煉固定敵陣與規則（卡池、預算、縱深、type_cap、技能）是否真的套到雙方、_trial_rules 與舊 10 關行為是否相同。
繁中、1200 字內，每條附 檔案:行號，最多 10 條，標 P0／P1／P2。最後一行「結論：可／有條件／不可」。
