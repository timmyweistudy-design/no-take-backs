請讀 docs/2026-11-03-free-placement-plan-v6.md（第六輪方案初稿：捨棄格子、自由排兵、按住滑動擺兵、部署區放大到半場／全場），再自己讀程式驗證（重點：game/scripts/core/battle_sim.gd、army.gd、ai_army.gd、ai_turns.gd、hard_ai.gd、turn_placement.gd、formations.gd、ruleset.gd、mirror_check.gd、game/scripts/game/battle_code.gd、puzzles.gd、game/scripts/ui/game_screens.gd、replay_view.gd、lobby_view.gd、game/tools/golden.gd、compat.gd、seal_codes.gd、unit_eval.gd、balance2.gd、game/tests/run_tests.gd）。可以上網查資料（自由擺放的確定性、陣型編碼、碰撞與密度），引用附網址。只寫意見，不改任何檔案。

你負責：確定性與鏡像（編號、排序、slot、量化）、舊格子陣型與舊代碼位元組不變的做法、代碼格式、合法性與防作弊、開戰重疊推開、全場部署的公平性、密度對平衡的影響與實驗設計、AI 擺法、效能、所有受影響系統是否列齊、測試能不能被騙。

格式（繁體中文，≤2,500 字），每項標〔X〕、附檔名:行號：
1. 初稿說錯或漏掉的事實。
2. 規則設計（§3）的問題與修正。
3. 受影響系統（§5）漏了什麼。
4. 驗收（§6）能不能被騙、要補什麼。
5. 里程碑順序。
6. 需要使用者決定的事（§9）有沒有漏或該刪。
不要只回報進度；直接讀檔，要完整回覆。
