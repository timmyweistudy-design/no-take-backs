第五輪實作審查第 1 輪。方案：docs/2026-11-03-custom-rules-and-ui-plan-v5.md（定稿 v1.0）。實作在 commit ddd15a8..HEAD（請用 git diff ddd15a8..HEAD -- game/ 看）。重點檔：
game/scripts/core/ruleset.gd、battle_sim.gd、army.gd、ai_army.gd、ai_turns.gd、hard_ai.gd、turn_placement.gd、game/scripts/game/presets.gd、battle_code.gd、save.gd、game/scripts/ui/ui_base.gd、lobby_view.gd、game_screens.gd、replay_view.gd、charts.gd、main.gd（版面檢查）、game/tests/run_tests.gd（test_rules_v5、test_sandbox_v5、test_battle_code_v5、存檔遷移）、game/tools/golden.gd、seal_codes.gd、check_all.sh、check_font_coverage.py、perf_probe.gd。

已驗證：GOLDEN_N=1000 COMPAT_N=1000 tools/check_all.sh 全過（測試 180 項、金標準 1000、舊兵相容 1000、40 筆封存 NTB2 代碼、字型涵蓋）；版面檢查 180 張截圖。

你負責：程式正確性、確定性（標準規則位元組不變、舊代碼用舊判定、沙盒不污染）、規則在所有入口都生效（擺放、輪流落子、暗擺、AI、載入陣型、對戰代碼、重播、覆盤、跳轉）、防卡死、存檔遷移、紀錄分欄與成就、測試能不能被騙、和方案 v1.0 的落差。只寫意見，不改任何檔案。

格式（繁體中文，≤2,500 字），每項標〔X〕、附檔名:行號：
1. 會造成錯誤結果或卡死的問題（P0／P1）。
2. 和方案定稿不一致的地方。
3. 測試或驗收的漏洞。
4. 次要問題。
5. 能不能結案：「可／有條件可（列條件）／不可」。
不要只回報進度；直接讀檔，要完整回覆。
