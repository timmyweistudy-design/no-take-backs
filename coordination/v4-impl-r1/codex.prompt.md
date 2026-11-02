這是《落子無悔》第四輪（新增五種兵）的實作審查第 1 輪。方案定稿在 docs/2026-11-02-new-units-plan-v4.md（§2 規則、§3 驗證）。
實作 commit：git show 7e0a0de（以及 a2546f0 的 N0a）。請讀程式驗證，重點檔案：
- game/scripts/core/battle_sim.gd（新兵規則、_support_point、_try_heal、_apply_heals、_splash_victims、_tie_less、戰鼓、破陣）
- game/scripts/core/unit_defs.gd、events.gd、ai_army.gd、ai_turns.gd、formations.gd、mirror_check.gd
- game/tools/compat.gd、golden.gd、unit_eval.gd、unit_eval_report.py
- game/tests/run_tests.gd 的 test_new_units、test_roster_ui
- game/scripts/game/roster.gd、game/scripts/ui/game_screens.gd 的 _ntypes／_allowed／AI 呼叫
注意：數值還在調（unit_defs 的 STATS 與常數會變），金標準與反制庫會在數值定案後重產，所以測試裡那兩項目前是紅的，不用回報。

請找：確定性／鏡像不變／同時結算被破壞的地方、和方案 §2 不一致的實作、測試測不到或會被騙的地方、相容檢查（compat.gd）的漏洞、解鎖與 AI 開放兵種的漏洞（例如 AI 或反制庫拿出未開放的兵、重播／對戰代碼帶未開放的兵）、驗收工具（unit_eval／report）會騙人的地方。
只寫意見，不改檔。輸出繁體中文 ≤2,000 字：每個問題附檔名:行號、嚴重度 P0～P3、具體修法。標〔X〕。不要只回報進度，要完整回覆。
