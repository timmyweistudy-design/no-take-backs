這是第四輪實作審查第 3 輪（最後一輪；這輪之後的修正會標「未經複查」）。
你第 2 輪的意見在 coordination/v4-impl-r2/codex.out.md。之後的改動：git diff 84fe76f..HEAD（含第 2 輪修正、三次平衡調整、新兵試玩關、困難 AI 改寫）。
請看：
1. 第 2 輪第 6～11 點是否修好（game/tools/unit_eval.gd、unit_eval_report.py、compat.gd）。
2. 新規則：狂戰士破陣擴散（battle_sim.gd 搜尋 BREACH_SPREAD）、破陣受傷 ×3/2（_vuln）、投彈兵打盾 ×5/2（BOMB_SHIELD_NUM／DEN）有沒有確定性、鏡像、同時結算的問題；測試（tests/run_tests.gd 的 test_new_units）測不測得到。
3. 新的困難 AI（game/scripts/core/hard_ai.gd）：候選陣型各和玩家上一局模擬一場挑最好的；有沒有偷看這一局、確定性、開放兵種的漏洞；make_counter_lib.gd 的驗證是否和遊戲一致、會不會騙人。
4. 新兵試玩殘局（game/data/puzzles.json 的 new_units、tools/validate_puzzles.gd 的 trial 規則、tests 的標準解檢查）。
5. 驗收結果 docs/balance-runs/v4-final/report.md 與方案 §12（docs/2026-11-02-new-units-plan-v4.md）的說法是否一致、有沒有誇大。
只寫意見、不改檔。繁體中文 ≤1,800 字，每點標〔X〕、P0～P3、附檔名:行號。不要只回報進度，要完整回覆。
