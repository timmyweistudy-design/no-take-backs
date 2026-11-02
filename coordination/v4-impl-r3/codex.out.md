已核對指定差異，未改檔。Python 在記憶體重算的報表與提交版一致；Godot 啟動即崩潰，本輪無法確認動態測試通過。

1. 〔X〕**P3｜第 2 輪 #6、#10、#11 的主要漏洞已修。** skip 現在驗兵種、開放數與索引；相容檢查驗固定陣型集合及解碼失敗；替換實驗驗四政策對手一致，空配對會報錯。見 `game/tools/unit_eval_report.py:64、89、118`、`game/tools/compat.gd:98、105`。

2. 〔X〕**P1｜#7 仍未完成，#8 僅部分完成。** 契約仍是資料自我背書，沒有綁定模擬／產生器程式內容，也不驗陣型代碼。我以合法資料改成任意 rules／pool、無關 commit、空 code，檢查仍通過。同池經典範圍及完整鍵已修，但不能據此宣稱實驗版本可追溯。見 `game/tools/unit_eval_report.py:62、75、133`、`game/tools/unit_eval.gd:58`；正式資料仍標 `abfd43f+dirty`（`docs/balance-runs/v4-final/report.md:3`）。

3. 〔X〕**P2｜覆蓋實驗仍有對手配對漏洞。** 檢查只驗 `(i,kk,k)`，計算卻以 `(i,opp)` 建字典；同一陣型的四個對手若共用 opp，會靜默覆寫。反例把全部 opp 改為 0，仍通過檢查，實際每套只剩一個對手。應驗對手公式、跨 kk 一致性及每套四個不同對手。見 `game/tools/unit_eval_report.py:95、198`。

4. 〔X〕**P2｜#9 的「實際覆蓋」仍不準確。** 鼓手分母是整場 tick，並非註解所稱存活 tick；早死也會被算成低覆蓋。醫者只量開戰部署，沒有量跟隨後的覆蓋。這不足以驗證戰鬥中的高覆蓋是否失控，亦不能直接推論「擺邊邊浪費」。見 `game/tools/unit_eval.gd:178、193、203`、`docs/2026-11-02-new-units-plan-v4.md:504`。

5. 〔X〕**P2｜新規則邏輯未見明顯順序／鏡像錯誤，但測試不足。** 擴散先收集合、結算才套狀態；倍率用整數，新增破陣下一 tick 才增傷，設計一致。現有測試只驗一次擴散與預設破陣的劍傷，未鎖住同 tick 首次破陣不增傷、多狂戰士重疊、死亡仍擴散、半徑恰等於邊界，以及破陣盾兵的炸彈主擊／波及倍率。見 `game/scripts/core/battle_sim.gd:404、434、558、785`、`game/tests/run_tests.gd:1558、1574`。

6. 〔X〕**P1｜困難 AI 的驗收證據尚未成立。** 遊戲在保存本局前呼叫 AI，未見偷看；候選與反制庫也限制開放兵種，固定輸入及 RNG 下流程可重現。但驗證把受測陣型本身當上一局，僅代表玩家完全沿用陣型；且提交庫仍記困難 **73% < 普通 74%**，沒有新演算法通過的數據或群集區間。見 `game/scripts/ui/game_screens.gd:219、221`、`game/scripts/core/hard_ai.gd:18、63`、`game/tools/make_counter_lib.gd:59、64`、`game/data/counter_lib.json:3`。

7. 〔X〕**P3｜試玩標準解檢查已接上。** 五關皆標 trial，測試驗合法部署、勝利及使用主角兵種。惟 trial 的三星補驗直接 append，未驗合法性，須依賴另一套測試才能排除非法標準解；建議共用合法部署入口。見 `game/data/puzzles.json:1256`、`game/tests/run_tests.gd:434、461`、`game/tools/validate_puzzles.gd:31、94`。

8. 〔X〕**P2｜§12 結論應縮限。** 表格數字與報表一致，但「第 2 輪全部修正」過早；報表通過的是列出的局部門檻，未涵蓋 §3.4 的封存終驗、反制搜尋、全局指標及 snake5。另「4 隻以上 +7.5」混淆分組：+7.5 是 4～6，6 以上是 +6.8。見 `docs/2026-11-02-new-units-plan-v4.md:246、502、531`、`docs/balance-runs/v4-final/report.md:116、122`。