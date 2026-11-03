請先讀 docs/2026-11-03-custom-rules-and-ui-plan-v5.md（第五輪方案初稿：全面自訂規則＋版面大整理），再自己讀 repo 的程式驗證初稿裡的說法（重點：game/scripts/core/battle_sim.gd、unit_defs.gd、army.gd、ai_army.gd、ai_turns.gd、hard_ai.gd、formations.gd、turn_placement.gd、game/scripts/game/roster.gd、battle_code.gd、save.gd、puzzles.gd、game/scripts/ui/game_screens.gd、ui_base.gd、battle_view.gd、codex_view.gd、replay_view.gd、game/tools/golden.gd、compat.gd、make_counter_lib.gd、layout_check.sh、build_font.py、check_all.sh、game/tests/run_tests.gd）。

你負責的角度：**程式架構、確定性與鏡像不變、標準規則下金標準與舊對戰代碼完全不變的做法、規則物件與代碼格式、AI 吃任意卡池／任意金幣、讓子時的戰力與時間到判定、效能（人數上限）、存檔遷移、沙盒數值表的可行性、版面檢查與字級系統的程式做法、測試與驗收能不能被騙**。可以上網查資料（自訂規則大廳、確定性模擬參數化、遊戲 UI 字級），引用請附網址。只寫意見，不改任何檔案。

格式（繁體中文，≤2,500 字）：
1. **初稿裡說錯或漏掉的事實**：附檔名:行號當證據。
2. **R 線（自訂規則）的問題**：§3.1 欄位逐一看（範圍合不合理、有沒有會壞的組合）、§3.2 模擬器與 AI 改法的陷阱、§3.4 沙盒可行性與閘門。
3. **U 線（版面）程式面的問題**：字級常數、三種字型、圖表元件、版面檢查新規則怎麼做才不會被騙。
4. **驗收與測試**：哪些會被騙、要補什麼。
5. **里程碑順序**：要不要調整。
6. **需要使用者決定的事**：§9 有沒有漏或該刪的。
每項標〔X〕。不要只回報進度；直接讀檔，要完整回覆。
