你是《落子無悔》(Godot 4.6.2) 1.4.0 實作的程式審查。只讀。專案根目錄＝目前資料夾、遊戲在 game/。
第 11 大類（玩法 2.0，本批只做 §11.1 無盡塔；其餘記錄延後）：規劃 coordination/v140-impl/cat11-plan.md；方案 docs/2026-11-13-v1.4.0-plan.md §11、§11.11；差異 coordination/v140-impl/cat11-r1/diff.patch（含新檔 game/scripts/game/tower.gd）。
請檢查：①舊場位元組：無盡塔是否只走既有挑戰碼／自訂規則路徑、沒有改模擬或舊規則的序列化（handicap 開啟對代碼、戰績、成就、天梯、對戰紀錄 _record_match 有沒有副作用）；②tower_on 的生命週期：_start_mode 清掉後才設、重播／覆盤／再來一局／回標題、多局系列（rounds）時 tower_floor 與 tower_run 是否正確；輸的判定 w（平手？）；③_tower_open 續局、規則不合法回第 1 層的遞迴；試玩版鎖；④存檔新鍵驗型、清除戰績；⑤結果頁按鈕 bs.clear 與其他模式（車輪戰、每日練習、幽靈）互動；⑥測試是否足夠。
附行號。最多 6 條必改，600 字內。最後一行「結論：可／有條件／不可」。
