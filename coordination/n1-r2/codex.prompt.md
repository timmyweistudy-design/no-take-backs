# 程式輪 N1～N5（Codex 唯讀，第 2 輪：針對性複查）

你在第 1 輪（coordination/n1-r1/codex.out.md）抓到 12 項。Claude 已修正，未 commit 的工作樹就是修正後的版本（基準 8554893，用 `git diff 8554893 -- game/` 看）。
這一輪**只做三件事**，繁體中文、≤1,200 字、附檔案:行號：
1. 逐條核對 12 項：已解決／部分／未解決＋一句理由。
2. 修正有沒有引入**新的**錯誤（尤其：battle_sim.gd 的背水機制 RALLY、pick_counter、_update_charge；mirror_check.gd 的完整狀態比對；balance_report.py 的完整性檢查與 manifest；balance.sh 的反制搜尋；main.gd 的盲擺鎖定與遠征）。
3. 新增的「背水」（落後方剩餘戰力 < 對方 60% 時冷卻每 tick 多扣 2，＝攻速 ×1.5）：確定性、鏡像、在第④步讀「這一 tick 開始時的戰力」是否兩隊對稱？

Claude 已驗證：測試 51/51；三項「改壞會紅」（面向不鎖、推移算進衝鋒、反擊依順序）各自變紅；mirror_100 完整狀態 100/100；13 關驗證全過（工具失敗會 exit 1、三星要同一解）；平衡報表見 docs/balance-runs/n2-final/report.md（若已產生）。
最後一句：可否進入下一批（可／有條件可／不可）。不要改任何檔案。
