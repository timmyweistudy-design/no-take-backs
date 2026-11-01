# 程式輪 N1～N7（Codex 唯讀，第 3 輪＝本里程碑最後一輪）

第 2 輪你的意見在 coordination/n1-r2/codex.out.md（4 項部分＋2 項新增）。Claude 已修正並 commit 53f43fc（上一版 8554893）。請看 `git diff 8554893 53f43fc -- game/`。
只做：
1. 核對第 2 輪的 #4、#6、#7、#12 與兩項新增（反制搜尋錯誤列、balance.sh 掃描）：已解決／未解決。
2. 本批新增的程式有沒有新錯誤：
   - battle_sim.gd 擊殺歸屬改為「這一 tick 傷害最高者＋鏡像鍵」。
   - main.gd 三層繪製、MVP 改勝方、判詞、試玩紀錄 _pt_entry、背水提示。
   - save.gd 改 copy_absolute／rename_absolute＋讀回驗證。
   - data/strings.csv.import 改 keep。
3. Claude 已驗證：
   - 測試 51/51。
   - 完整狀態鏡像 100/100（含 kills、wp_for、rally）。
   - 匯出的 Windows build 實際執行截圖 9 張零錯誤。
繁體中文、≤1,000 字、附檔案:行號。最後一句：本里程碑可否結案（可／有條件可／不可）。不要改任何檔案。
