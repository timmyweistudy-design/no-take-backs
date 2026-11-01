# 程式輪 N1～N5 第一批（Codex 唯讀審查，最多三輪的第 1 輪）

使用者要求「依計劃全做到底」。Claude 已實作優化方案（docs/2026-11-01-optimization-plan.md）的 N1～N5 第一批，commit 8554893（上一版 64e632d）。請看 `git diff 64e632d 8554893 -- game/scripts game/tools game/tests`（不用看 docs/balance-runs 的資料檔）。

已驗證（Claude 跑過）：Linux headless 測試 43/43；左右交換逐 tick 完整鏡像 100/100（tools/mirror_100.gd）；平衡工具 2.0 跑完（docs/balance-runs/n2-baseline/report.md）；13 關殘局驗證全過（docs/balance-runs/puzzle-validation.jsonl）；Windows 實際渲染截圖正常（docs/shots-n4/）。

請用繁體中文、≤1,500 字，每條標 嚴重／中／低、附檔案:行號：
1. **確定性或鏡像漏洞**（battle_sim.gd 重寫了：快照陣列、面向鎖定、衝鋒、反擊、SHA-256 指紋、fast 模式）。
2. **規則與方案不符**（B1 三項、A2 蛇行、E3 代碼、F1 最後時刻條件）。
3. **測試假綠燈**（tests/run_tests.gd 新增的測試是否真的會在規則壞掉時變紅）。
4. **工具錯誤**：balance.sh／balance2.gd／balance_report.py 的分片合併、紅線判斷、搜尋與反制邏輯；validate_puzzles.gd 的判準。
5. **遊戲層明顯 bug**：scripts/ui/main.gd（狀態切換、輪流落子、盲擺、遠征更換次數、成就判定、存檔）、save.gd 原子寫入、steam.gd。
最後一句：這批可否繼續往下做（可／有條件可／不可）。不要改任何檔案。
