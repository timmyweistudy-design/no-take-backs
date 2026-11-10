《落子無悔》V1.6.1 實作審查，第 1 輪（共三輪）。只讀檔、不改檔、不執行會改東西的指令。
方案：docs/2026-11-10-v1.6.1-plan.md。實作裁決（含不照方案的理由）：coordination/v161-impl/ledger.md。
本版改動：git diff 694446c..HEAD（已存成 coordination/v161-impl/r1-diff.patch；主要在 game/scripts/ui/screens/game_v16.gd、game/scripts/game/v16_*.gd、workshop.gd、steam.gd、save.gd、battle/*.gd、lobby_view.gd、tests/suites/v161.gd）。
鐵則：FINGERPRINT b8fe741bcbfcf800 與舊代碼位元組不能變；模擬只用整數、畫面狀態不能進模擬；新存檔欄位可選且要驗型；新字串進 strings.csv。
請找「會壞掉、存檔出錯、和方案不符、測不到」的問題：
1. 逐項看 F1～F8、B1、A1～A13、N1～N6、D1／D2／D4／D7 有沒有做對、有沒有漏（對照方案與 ledger）。
2. 特別查：背景執行緒（教練 co_thread、三考 trio_thread）的競態與離開時收尾；NTP4／三考碼的驗證（竄改、超量、試玩版）；存檔新欄位（coached、medals、rush_day、trio_stars、notebook h、clog、daily_pend ver）的清洗與清除資料；手把與觸控路徑（改名輸入、取消推演、練習場）；版面（新面板高度、分頁）。
3. 最多 12 條必改，每條：檔名:行號、問題、怎麼重現、建議改法。
繁體中文，1800 字以內。最後一行：結論：可／有條件／不可。
