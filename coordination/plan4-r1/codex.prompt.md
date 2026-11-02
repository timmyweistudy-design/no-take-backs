請先讀 docs/2026-11-02-new-units-plan-v4.md（第四輪方案初稿：新增五種兵種），再自己讀 repo 的程式驗證初稿裡的說法（重點：game/scripts/core/battle_sim.gd、unit_defs.gd、army.gd、ai_army.gd、ai_turns.gd、formations.gd、game/scripts/ui/game_screens.gd、sprite_cache.gd、codex_view.gd、game/scripts/game/codex.gd、save.gd、game/tools/balance.gd、golden.gd、make_counter_lib.gd、game/tests/run_tests.gd；以及 docs/balance-runs/s6-decision.md）。

你負責的角度：**程式正確性、確定性與鏡像不變、同時結算、平衡方法與驗收門檻能不能被騙、測試、效能、存檔相容、排版的程式架構**。可以上網查資料（自動對戰遊戲的範圍傷害／補血／光環設計、確定性模擬），引用請附網址。只寫意見，不改任何檔案。

格式（繁體中文，≤2,500 字）：
1. **初稿裡說錯或漏掉的事實**：附檔名:行號當證據。
2. **規則初稿的問題**：逐一看長槍兵、投彈兵、醫者、狂戰士、鼓手，指出會破壞確定性、鏡像、同時結算，或實作上有陷阱的地方，附修正建議。
3. **數值初稿**：一眼看得出過強／過弱的，附你的推算。
4. **五種兵的選擇**：同意、修改或替換？替換要具體說理由。
5. **驗收門檻與測試**：哪些會被騙、要補什麼。
6. **里程碑與分批**：要不要調整順序（例如 N0 範圍）。
7. **需要使用者決定的事**：§9 有沒有漏或該刪的。
每項標〔X〕。不要只回報進度；直接讀檔，要完整回覆。
